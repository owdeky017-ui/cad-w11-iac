#!/bin/bash
# Install your Python environment
apt-get update -y
apt-get install -y python3-venv git
python3 -m venv venv
source venv/bin/activate
# Clone the latest app directly onto the server
git clone https://github.com/owdeky017-ui/cad-w11-app.git
cd cad-w11-app
pip install -r requirements.txt
# Run Uvicorn on port 80 bound to all interfaces (background job with log file)
nohup uvicorn main:app --host 0.0.0.0 --port 80 > uvicorn.log 2>&1 &
