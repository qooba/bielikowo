# Build Mistral.rs on T4

## NVIDIA 535 CUDA 12.2
```
sudo apt update && sudo apt upgrade -y
sudo add-apt-repository ppa:graphics-drivers/ppa
sudo apt update

sudo apt install -y nvidia-driver-535
sudo reboot


wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
wget https://developer.download.nvidia.com/compute/cuda/12.2.0/local_installers/cuda-repo-ubuntu2204-12-2-local_12.2.0-535.54.03-1_amd64.deb
sudo dpkg -i cuda-repo-ubuntu2204-12-2-local_12.2.0-535.54.03-1_amd64.deb
sudo cp /var/cuda-repo-ubuntu2204-12-2-local/cuda-*-keyring.gpg /usr/share/keyrings/
sudo apt-get update
sudo apt-get -y install cuda

sudo apt install python3-pip git pkg-config libssl-dev

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh


export PATH=$HOME/.local/bin:$PATH
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="/usr/local/cuda-12/bin:$PATH"

pip3 install maturin
pip3 install patchelf

git clone https://github.com/EricLBuehler/mistral.rs.git

cd mistral.rs
# inst Cargo.toml add 
# pyo3 = { version = "0.22.4", features = ["full", "extension-module", "either","experimental-async", "abi3", "abi3-py38", "anyhow"  ] }

cd mistral.rs/mistralrs-pyo3/
maturin build --release --features cuda  --compatibility manylinux2014 --skip-auditwheel

```

## INSTALL 

wget https://github.com/qooba/bielikowo/raw/refs/heads/main/packages/mistralrs-0.4.0-cp38-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
pip3 install mistralrs-0.4.0-cp38-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl

rm cuda-repo-ubuntu2204-12-2-local_12.2.0-535.54.03-1_amd64.deb
rm mistralrs-0.4.0-cp38-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl

## TEST BIELIK

```bash
cat <<EOF > bielik_test.py
import random
from mistralrs import ChatCompletionRequest, Runner, Which


class BielikRunner:

    def __init__(self, quantized_model_id: str, quantized_filename: str):
        self.runner = Runner(
            which=Which.GGUF(quantized_model_id=quantized_model_id, quantized_filename=quantized_filename )
        )

    def chat_completion(self, prompt: str) -> str:
        res = self.runner.send_chat_completion_request(
            ChatCompletionRequest(
                model="mistral",
                messages=[
                    #{"role": "system", "content": persona},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=256,
                presence_penalty=1.0,
                top_p=random.uniform(0.1, 0.5),
                temperature=random.uniform(0.1, 0.5),
            )
        )
        
        return res.choices[0].message.content

runner = BielikRunner("speakleash/Bielik-11B-v2.3-Instruct-GGUF", "Bielik-11B-v2.3-Instruct.Q8_0.gguf")

result = runner.chat_completion("Witaj świecie")
print(result)
EOF
```

```bash
cat <<EOF > pllum_test.py
import random
from mistralrs import ChatCompletionRequest, Runner, Which


class PLLuMRunner:

    def __init__(self, model_id: str):
        self.runner = Runner(which=Which.Plain(model_id=model_id))

    def chat_completion(self, prompt: str) -> str:
        res = self.runner.send_chat_completion_request(
            ChatCompletionRequest(
                model="mistral",
                messages=[
                    #{"role": "system", "content": persona},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=256,
                presence_penalty=1.0,
                top_p=random.uniform(0.1, 0.5),
                temperature=random.uniform(0.1, 0.5),
            )
        )
        
        return res.choices[0].message.content

runner = PLLuMRunner("CYFRAGOVPL/Llama-PLLuM-8B-chat")

result = runner.chat_completion("Witaj świecie")
print(result)
EOF
```

# Prepare image


```bash
az vm deallocate --resource-group BIELIK_VM --name bielikVM1

---
cd ../../bielik-w-ray/terraform/vm-image/


MANAGED_DISK_ID=$(az vm show --name bielikVM1 --resource-group BIELIK_VM --query "storageProfile.osDisk.managedDisk.id" --output tsv)

terraform init
terraform apply --var managed_disk_id=$MANAGED_DISK_ID

---

cd ../gallery

MANAGED_IMAGE_ID=$(az image show --name vm-image --resource-group BIELIK_IMAGE --query "id" --output tsv)

terraform init
terraform apply --var managed_image_id=$MANAGED_IMAGE_ID

az sig image-version list --resource-group BIELIK_GALLERY_PY --gallery-name bielikGalleryPy --gallery-image-definition bielik-vm-image-py

---
cd ../vm-image

terraform destroy --var managed_disk_id=$MANAGED_DISK_ID

cd ../../../bielik-w-azure-vm/terraform/
az vm start --resource-group BIELIK_VM --name bielikVM1
terraform destroy

---

cd ../../bielik-w-ray/terraform/ray-cluster/
mkdir ssh
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f ./ssh/id_rsa

terraform init
terraform apply

HEAD_IP=$(az vm list-ip-addresses --name ray-head-vm --resource-group BIELIK_RAY --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)
ssh -i ./ssh/id_rsa -Y bielik@$HEAD_IP

ssh bielik@$HEAD_IP -i ./ssh/id_rsa -L 8265:localhost:8265 -TN /bin/false

ssh bielik@$HEAD_IP -i ./ssh/id_rsa -L 8888:localhost:8888 -TN /bin/false

terraform destroy


chown -R $USER /tmp/ray/

```

RAY VERSION 2.43.0

## TEST RAY
```python
import ray
import subprocess

ray.init(address="auto", ignore_reinit_error=True)  # Connect to Ray cluster

@ray.remote(num_gpus=1)
def get_gpu_info():
    """Returns GPU details from a Worker Node using `nvidia-smi`."""
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,memory.total", "--format=csv,noheader"],
            capture_output=True,
            text=True,
            check=True
        )
        gpu_info = result.stdout.strip()
        return {
            "worker": ray.get_runtime_context().node_id,
            "gpu_info": gpu_info
        }
    except Exception as e:
        return {"worker": ray.get_runtime_context().node_id, "error": str(e)}

# Launch tasks on available GPU workers
gpu_info_futures = [get_gpu_info.remote() for _ in range(2)]  # Adjust for max workers

# Retrieve and print GPU info from workers
gpu_info_results = ray.get(gpu_info_futures)

print("GPU Info from Workers:")
for info in gpu_info_results:
    print(info)
```


```python
import ray

ray.init(address="auto", ignore_reinit_error=True)  # Connect to Ray cluster

# Sample texts
texts = [
    "Witaj świecie",
    "Napisz wiersz",
    "Opowiedz o sobie",
    "Napisz fraszkę"
]

BATCH_SIZE = 2

# Split texts into batches
batches = [texts[i:i + BATCH_SIZE] for i in range(0, len(texts), BATCH_SIZE)]

@ray.remote(num_gpus=1)
def process_batch(batch):
    import random
    from mistralrs import ChatCompletionRequest, Runner, Which

    runner = Runner(which=Which.GGUF(quantized_model_id="speakleash/Bielik-11B-v2.3-Instruct-GGUF", quantized_filename="Bielik-11B-v2.3-Instruct.Q8_0.gguf"))

    res = [runner.send_chat_completion_request(
            ChatCompletionRequest(
                model="mistral",
                messages=[
                    #{"role": "system", "content": persona},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=256,
                presence_penalty=1.0,
                top_p=random.uniform(0.1, 0.5),
                temperature=random.uniform(0.1, 0.5),
            )
        ).choices[0].message.content for prompt in batch]
    
    return res

# Send batches to workers
futures = [process_batch.remote(batch) for batch in batches]

# Retrieve processed results
processed_batches = ray.get(futures, timeout=1000)

# Merge all results
processed_texts = [text for batch in processed_batches for text in batch]

# Print results
print("Processed Texts:")
for text in processed_texts:
    print(text)
```

```python
import ray

ray.init(address="auto", ignore_reinit_error=True)  # Connect to Ray cluster

# Sample texts
texts = [
    "Witaj świecie",
    "Napisz wiersz",
    "Opowiedz o sobie",
    "Napisz fraszkę"
]

BATCH_SIZE = 2

# Split texts into batches
batches = [texts[i:i + BATCH_SIZE] for i in range(0, len(texts), BATCH_SIZE)]

@ray.remote(num_gpus=1)
def process_batch(batch):
    import random
    from mistralrs import ChatCompletionRequest, Runner, Which

    runner = Runner(which=Which.Plain(model_id="CYFRAGOVPL/Llama-PLLuM-8B-chat"))

    res = [runner.send_chat_completion_request(
            ChatCompletionRequest(
                model="mistral",
                messages=[
                    #{"role": "system", "content": persona},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=256,
                presence_penalty=1.0,
                top_p=random.uniform(0.1, 0.5),
                temperature=random.uniform(0.1, 0.5),
            )
        ).choices[0].message.content for prompt in batch]
    
    return res

# Send batches to workers
futures = [process_batch.remote(batch) for batch in batches]

# Retrieve processed results
processed_batches = ray.get(futures, timeout=1000)

# Merge all results
processed_texts = [text for batch in processed_batches for text in batch]

# Print results
print("Processed Texts:")
for text in processed_texts:
    print(text)
```