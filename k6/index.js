import http from 'k6/http';
import { sleep } from 'k6';


const my_stream_name = 'tf-test-stream'

// export const options = {
//     vus: 2,
//     duration: '10s',
// };

let temp = Math.floor(Math.random() * 101);
let humi = Math.floor(Math.random() * 101);
let pres = Math.floor(Math.random() * 101);
let co2 = Math.floor(Math.random() * 101);
let timestamp = new Date();
const devi = '51539982'
let err = 0

export default function () {
    const url = 'https://9rtuubvy0f.execute-api.ap-northeast-2.amazonaws.com/s1/streams/tf-test-stream/record';
    const payload = JSON.stringify({
        "result": "success",
        "error_code": err,
        "device_id": devi,
        "coord": {
            "lon": "-8.61",
            "lat": "41.15"
        },
        "server_time": timestamp,
        "temperature": temp,
        "pressure": pres,
        "humidity": humi,
        "co2": co2});
        
    const data_set = JSON.stringify({
            "Data": payload,
            "PartitionKey": "count",
            "StsreamName": my_stream_name
        })

    const params = {
        headers: {
            'Content-Type': 'application/json',
        },
    };

    http.put(url, data_set, params);
    sleep(1);
}