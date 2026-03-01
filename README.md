# Development and Validation of Prognostic Scores in Logistic Regression 📊🏥

This repository contains the full technical implementation, statistical analysis, and dissertation for my Master's Thesis in **Advanced Multivariate Data Analysis and Big Data** at the **University of Salamanca (USAL)**.

## 🎯 Project Overview
The research focuses on the clinical development and statistical validation of prognostic scores. By leveraging real-world electronic health records, the project transforms complex logistic regression models into practical clinical tools.

## 📊 Data Source
The analysis is conducted using the **"Heart Failure Prediction from Clinical and Laboratory Data in Zigong"** dataset, hosted on **PhysioNet** (Gu et al., 2022).
* **Population**: 2,000+ patients with heart failure.
* **Target**: Predicting 6-month mortality (`death.within.6.months`).

## 🛠️ Technical Stack & Methodology
* **Statistical Computing**: **R** (Data cleaning, MICE imputation, LASSO, Random Forest, and Model Validation).
* **Document Engineering**: Full dissertation authored in **LaTeX** to ensure rigorous mathematical formatting and structured documentation.
* **Presentations**: Technical defense developed using the **LaTeX/Beamer** class for high-quality scientific communication.
* **Standards**: Following **TRIPOD** guidelines for transparent reporting of multivariable prediction models.

## 📂 Repository Structure
* 📁 **`analysis/`**: 
    * `Prognostic_Model_Pipeline.R`: End-to-end R script including data preprocessing, feature selection, and model calibration.
* 📁 **`Data/`**: 
    * `heart_failure_zigong_data.csv`: Clinical dataset from PhysioNet used for the study.
* 📁 **`docs/`**: 
    * `Master_Thesis_Antonio_Luque.pdf`: Complete written dissertation (LaTeX-generated).
    * `Thesis_Defense_Beamer.pdf`: Summary presentation slides (Beamer-generated).
* 📄 **`LICENSE`**: MIT License.

## 🚀 Key Insights
1.  **Missing Data**: Successfully handled missing clinical values using **MICE** (Multivariate Imputation by Chained Equations) to preserve statistical power.
2.  **Predictive Accuracy**: The final model demonstrates robust **Discrimination (AUC)** and **Calibration (Hosmer-Lemeshow)**, effectively predicting 6-month mortality risk.
3.  **Clinical Translation**: Logistic coefficients were scaled into an integer-based **Score**, making the model ready for real-world clinical use.

---
*Developed by Antonio Luque Ruiz - University of Salamanca.*
