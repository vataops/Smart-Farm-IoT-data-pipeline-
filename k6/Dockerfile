FROM grafana/k6

WORKDIR /home
ADD index.js /home/index.js

RUN k6 run --vus 10 --duration 30s index.js
