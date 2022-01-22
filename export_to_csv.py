from numpy import dtype
import pandas as pd
import requests


response = requests.get('http://localhost:8080/api/v1/query?query=rate(nginx_ingress_controller_nginx_process_requests_total[5m])')
request_per_second = response.json()['data']['result'][0]['value'][1]


response = requests.get('http://localhost:8080/api/v1/query?query=rate(nginx_ingress_controller_nginx_process_cpu_seconds_total[5m])')
cpu_per_second = response.json()['data']['result'][0]['value'][1]


response = requests.get('http://localhost:8080/api/v1/query?query=rate(nginx_ingress_controller_nginx_process_resident_memory_bytes[5m])')
memory = response.json()['data']['result'][0]['value'][1]

csv_dict = {
    'Average requests per second' : [request_per_second],
    'Average memory usage per second': [memory],
    'Average CPU usage per second': [cpu_per_second]
}

df = pd.DataFrame.from_dict(csv_dict)

df.to_csv('report.csv')
