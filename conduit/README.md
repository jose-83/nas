## Check the traffic of the server
First run:
```bash
sudo apt update
sudo apt install -y geoip-bin geoip-database
```
Then copy shell file and run:
```bash
chmod +x iran-geoip-sample.sh
```
and then run:
```bash
./iran-geoip-sample.sh 200000
```