markdown
# Marathon Finish Time Prediction

## Mission & Problem
East Africa produces some of the world's best distance runners, but talent is often spotted informally and too late. This project predicts a runner's marathon finish time from their age, gender, and first-half split times, giving coaches an early, data-driven signal to identify and develop promising endurance athletes.

## Dataset
Finishers of the Boston Marathon 2015–2017: 79,638 runners and 27 columns covering age, gender, checkpoint splits (5K–40K), and official finish time. Source: [Boston Marathon Results on Kaggle](https://www.kaggle.com/datasets/rojour/boston-results). The three years are merged into `summative/linear_regression/data/boston_marathon_2015_2017.csv`.

## Live API
The prediction API is deployed on Render and documented with Swagger UI:

**Swagger UI:** [https://linear-regression-model-tru9.onrender.com/docs](https://linear-regression-model-tru9.onrender.com/docs)

**Prediction endpoint:** `POST https://linear-regression-model-tru9.onrender.com/predict`

> Note: the API runs on Render's free tier, so the first request after a period of inactivity can take up to a minute while the service wakes up.

## Video Demo
**YouTube:** [Watch the demo](ADD_YOUR_YOUTUBE_LINK_HERE)

## Running the Mobile App
The Flutter app is in `summative/FlutterApp/marathon_predictor` and sends requests to the live API above.

1. Install [Flutter](https://docs.flutter.dev/get-started/install) and connect an Android emulator or a physical device with USB debugging enabled.
2. From the project root, move into the app folder:

cd summative/FlutterApp/marathon_predictor

3. Install the dependencies:

flutter pub get

4. Run the app:

flutter run

5. Enter the runner's age, gender (M or F), and split times in minutes (5K, 10K, 15K, 20K, Half), then tap **Predict**. The predicted finish time appears below the button, and missing or out-of-range values show a clear error message.

## Project Structure

linear_regression_model/
└── summative/
├── linear_regression/
│ ├── multivariate.ipynb
│ └── data/
├── API/
│ ├── prediction.py
│ └── requirements.txt
├── FlutterApp/
│ └── marathon_predictor/
└── pyproject.toml


## Models
Four regression models were built and compared with scikit-learn: SGD linear regression (gradient descent), OLS linear regression, a decision tree, and a random forest. The random forest gave the lowest test loss (MSE ≈ 121.7, RMSE ≈ 11 minutes) and is the model saved and served by the API.
