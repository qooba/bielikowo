#!/bin/bash

docker run -it --name bielik -v $(pwd)/../../bielikowo:/bielikowo -w /bielikowo --rm qooba/bielikowo 

