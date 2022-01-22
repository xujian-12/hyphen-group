## Prerequisite

Install the following components before start:

```
Docker
Kind
pip3 install requests
pip3 install pandas
```

## Procedures

1. Run `sh automation.sh`
2. Once the script completed. You can access two web applications by http://localhost/foo and http://localhost/foo
3. Prometheus server can be access by  http://localhost:8080
4. Report are stored in `report.csv`

## Improvement

1. Use better benmark tool to have proper testing on Ingress Controller.
2. Use combinations of promql to have better reports.

## Cleanup

```
kind delete cluster --name hg-test
```
