# KfoldCV_LASSO_existing_BAGs.py
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path
from sklearn.pipeline import Pipeline
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LassoCV
from sklearn.model_selection import StratifiedKFold
from sklearn.metrics import r2_score, mean_absolute_error
import warnings

warnings.filterwarnings("ignore", category=UserWarning)

# ----------------- CONFIG -----------------
RANDOM_STATE = 42
N_SPLITS = 5                      # K in K-fold CV
FIG_DIR = Path("/Users/snemati/Documents/ABC_BrainAge/Figures")
OUT_DIR = FIG_DIR
FIG_DIR.mkdir(parents=True, exist_ok=True)

# File paths - update based on path in your computer
BEHAVIOR_PATH = "/Users/snemati/Documents/ABC_BrainAge/Output//BrainAge/ABC_Beh_AlignedDirection_afterStandardization_220Th.xlsx"
BRAINAGE_PATH = "/Users/snemati/Documents/ABC_BrainAge/Output/BrainAge/ABC_globalBrainAge.xlsx"

# Age strata (for stratifying folds)
N_AGE_BINS = 5

# Age groupings for plotting
AGE_GROUPS = {
    "All ages": lambda a: np.ones_like(a, dtype=bool),
    "Age 20-50": lambda a: (a >= 20) & (a <= 50),
    "Age >50": lambda a: a > 50
}
# ------------------------------------------

# ----------------- LOAD DATA -----------------
df_beh = pd.read_excel(BEHAVIOR_PATH)
df_age = pd.read_excel(BRAINAGE_PATH)
df = pd.merge(df_age, df_beh, on="Subject_ID", how="inner")
print(f"Loaded merged dataframe: {df.shape[0]} subjects, {df.shape[1]} columns")

if "Age" not in df.columns:
    raise RuntimeError("Column 'Age' not found in merged data. Rename your age column to 'Age'.")

# ----------------- FIND BAG COLUMNS -----------------
bag_cols = [c for c in df.columns if c.endswith("_BAG")]
if not bag_cols:
    raise RuntimeError("No columns ending with '_BAG' found. Please check your file.")
print("Found BAG columns:", bag_cols)

# ----------------- PREPARE PREDICTORS -----------------
# Drop leakage columns: ID, Age, BrainAge and BAG columns
drop_cols = ["Subject_ID", "Age", "Age_normalized"] + [c for c in df.columns if "BrainAge" in c or "brainage" in c or "Brainager" in c or "BAG"in c] + bag_cols
X_df = df.drop(columns=[c for c in drop_cols if c in df.columns], errors='ignore')
X_df = X_df.select_dtypes(include=[np.number])  # numeric predictors only
feature_names = X_df.columns.tolist()
X = X_df.values
ids = df["Subject_ID"].values
ages = df["Age"].values
print(f"Using {X.shape[1]} numeric predictors.")

# ----------------- CREATE AGE STRATA -----------------
try:
    age_strata = pd.qcut(ages, q=N_AGE_BINS, labels=False, duplicates='drop')
except ValueError:
    age_strata = pd.cut(ages, bins=N_AGE_BINS, labels=False)
age_strata = np.asarray(age_strata)
n_strata = len(np.unique(age_strata))
print(f"Using {n_strata} age strata for StratifiedKFold.")

# ----------------- MAIN: K-FOLD CV FOR EACH BAG (LASSO) -----------------
summary_rows = []
for bag_col in bag_cols:
    print("\n" + "="*60)
    print(f"Running stratified {N_SPLITS}-fold CV for target: {bag_col}")
    y = df[bag_col].values.astype(float)

    # Prepare storage for out-of-fold predictions and coefficients
    n = X.shape[0]
    oof_preds = np.full(n, np.nan)
    fold_coefs = np.zeros((N_SPLITS, X.shape[1]))

    skf = StratifiedKFold(n_splits=N_SPLITS, shuffle=True, random_state=RANDOM_STATE)

    fold_no = 0
    for train_idx, test_idx in skf.split(X, age_strata):
        fold_no += 1
        print(f" Fold {fold_no}: train {len(train_idx)} / test {len(test_idx)}")

        # Pipeline: median imputation only (no scaling)
        preproc = Pipeline([("imputer", SimpleImputer(strategy="median"))])
        X_train_p = preproc.fit_transform(X[train_idx])
        X_test_p = preproc.transform(X[test_idx])

        # LassoCV (alpha tuned by inner CV)
        lasso = LassoCV(cv=5, random_state=RANDOM_STATE, max_iter=20000)
        lasso.fit(X_train_p, y[train_idx])

        # Predict on test fold
        y_pred_fold = lasso.predict(X_test_p)
        oof_preds[test_idx] = y_pred_fold

        # Save coefficients (coefs can be positive/negative)
        fold_coefs[fold_no-1, :] = lasso.coef_

        # Print fold metrics
        r2f = r2_score(y[test_idx], y_pred_fold)
        maef = mean_absolute_error(y[test_idx], y_pred_fold)
        rf_corr = np.corrcoef(y[test_idx], y_pred_fold)[0, 1] if len(test_idx) > 1 else np.nan
        print(f"  Fold {fold_no}: R²={r2f:.3f}, MAE={maef:.2f}, r={rf_corr:.3f}")

    # Overall metrics (out-of-fold)
    overall_r2 = r2_score(y, oof_preds)
    overall_mae = mean_absolute_error(y, oof_preds)
    overall_r = np.corrcoef(y, oof_preds)[0, 1]
    print("\n Cross-validated overall metrics:")
    print(f"  R² = {overall_r2:.3f}, MAE = {overall_mae:.2f}, r = {overall_r:.3f}")

    # Dataframe of predictions
    df_preds = pd.DataFrame({"Subject_ID": ids, "Age": ages, "y_true": y, "y_pred": oof_preds})

    # ---------- Per-age-group metrics ----------
    group_metrics = {}
    for gname, cond in AGE_GROUPS.items():
        mask = cond(df_preds["Age"].values)
        if mask.sum() == 0:
            group_metrics[gname] = {"N": 0, "R2": np.nan, "MAE": np.nan, "r": np.nan}
        else:
            y_t = df_preds.loc[mask, "y_true"].values
            y_p = df_preds.loc[mask, "y_pred"].values
            group_metrics[gname] = {
                "N": len(y_t),
                "R2": r2_score(y_t, y_p) if len(y_t) > 1 else np.nan,
                "MAE": mean_absolute_error(y_t, y_p),
                "r": np.corrcoef(y_t, y_p)[0, 1] if len(y_t) > 1 else np.nan
            }

    print(bag_col, "missing OOF preds:", np.sum(np.isnan(oof_preds)))

    # ---------- Plot Predicted vs Actual (3 panels) ----------
    def annotate_ax(ax, text):
        ax.text(0.02, 0.98, text, transform=ax.transAxes, fontsize=9,
                verticalalignment="top", bbox=dict(facecolor="white", alpha=0.8, edgecolor="none"))

    fig, axes = plt.subplots(1, 3, figsize=(18, 5), sharey=True)
    for ax, (gname, cond) in zip(axes, AGE_GROUPS.items()):
        mask = cond(df_preds["Age"].values)
        ax.set_title(gname)
        if mask.sum() == 0:
            ax.text(0.5, 0.5, "No subjects", ha="center", va="center")
            continue
        y_t = df_preds.loc[mask, "y_true"].values
        y_p = df_preds.loc[mask, "y_pred"].values
        ax.scatter(y_t, y_p, s=40, alpha=0.85, edgecolor="k", linewidth=0.2)
        minv, maxv = min(y_t.min(), y_p.min()), max(y_t.max(), y_p.max())
        ax.plot([minv, maxv], [minv, maxv], "k--", linewidth=1)
        ax.set_ylim(14, 80)
        ax.set_xlabel(f"Actual {bag_col} (years)")
        if gname == "All ages":
            ax.set_ylabel(f"Predicted {bag_col} (years)")
        gm = group_metrics[gname]
        annotate_ax(ax, f"N={gm['N']}\nR²={np.nan_to_num(gm['R2']):.2f}, "
                        f"MAE={np.nan_to_num(gm['MAE']):.2f}, r={np.nan_to_num(gm['r']):.2f}")

    fig.suptitle(f"Predicted vs Actual— {bag_col} (Stratified {N_SPLITS}-fold CV, LASSO)", fontsize=14)
    fig.tight_layout(rect=[0, 0.03, 1, 0.95])
    plot_out = OUT_DIR / f"KfoldCV_Pred_vs_Actual_{bag_col}_LASSO.png"
    fig.savefig(plot_out, dpi=300)
    plt.close(fig)
    print("Saved plot:", plot_out)

    # ---------- Save OOF predictions ----------
    preds_out = OUT_DIR / f"KfoldCV_OOF_predictions_{bag_col}_LASSO.csv"
    df_preds.to_csv(preds_out, index=False)
    print("Saved OOF predictions:", preds_out)

    # ---------- Aggregate coefficients ----------
    # We report mean absolute coefficient across folds as feature "importance"
    mean_abs_coef = np.mean(np.abs(fold_coefs), axis=0)
    coef_df = pd.DataFrame({"feature": feature_names, "coef_mean_abs": mean_abs_coef})
    coef_df = coef_df.sort_values("coef_mean_abs", ascending=False).reset_index(drop=True)
    coef_out = OUT_DIR / f"KfoldCV_LASSO_coeffs_{bag_col}.csv"
    coef_df.to_csv(coef_out, index=False)
    print("Saved aggregated coefficients:", coef_out)

    # ---------- Record summary ----------
    summary_rows.append({
        "BAG_measure": bag_col,
        "CV_R2": overall_r2,
        "CV_MAE": overall_mae,
        "CV_r": overall_r,
        "N_subjects": n
    })

# ---------- Save summary table ----------
summary_df = pd.DataFrame(summary_rows)
summary_out = OUT_DIR / "KfoldCV_LASSO_BAG_summary.csv"
summary_df.to_csv(summary_out, index=False)
print("\nSaved CV summary:", summary_out)

# ---------- Quick data check ----------
print(df[[c for c in bag_cols]].isna().sum())
missing_ids = df.loc[df[bag_cols[0]].isna(), "Subject_ID"] if bag_cols else []
print("Subjects missing first BAG column:", missing_ids.tolist())
