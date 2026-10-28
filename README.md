# CompSys A1
To run fauxgrep-mt, use the following command:
```bash
./fauxgrep-mt -n {number_of_cpu_cores} {any_needle} ./{data_file}
```
To run fhistogram-mt, use the following command:
```bash
./fhistogram-mt -n {number_of_cpu_cores} ./{data_file}
```
To run the benchmarks and tests:
```bash
make test
```
or 
```bash
bash bench_fauxgrep.sh 
bash bench_fhistogram.sh 
bash test_fauxgrep-mt.sh 
bash test_fauxgrep-mt.sh
```












