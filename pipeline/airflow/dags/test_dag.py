from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

dag = DAG(
    "test_dag",
    start_date=datetime(2024, 1, 1),
    schedule_interval="0 6 * * *",
    catchup=False,
)

def dummy_task():
    print("Test")
    return "success"

with dag:
    t1 = PythonOperator(
        task_id="test_task",
        python_callable=dummy_task,
    )
