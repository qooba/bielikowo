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

wget 

## TEST

```python
import random
from mistralrs import ChatCompletionRequest, Runner, Which


class MistralRSEngineRunner:

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

runner = MistralRSEngineRunner("speakleash/Bielik-11B-v2.3-Instruct-GGUF", "Bielik-11B-v2.3-Instruct.Q8_0.gguf")

result = runner.chat_completion("Witaj świecie")
print(result)
```

# Prepare image


```bash
az vm deallocate --resource-group BIELIK_VM --name bielikVM1

---

cd vm-image

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

cd ../ray-cluster
mkdir ssh
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f ./ssh/id_rsa

terraform init
terraform apply

HEAD_IP=$(az vm list-ip-addresses --name ray-head-vm --resource-group BIELIK_RAY --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)
ssh -i ./ssh/id_rsa -Y bielik@$HEAD_IP

ssh bielik@$HEAD_IP -i ./ssh/id_rsa -L 8265:localhost:9265 -TN /bin/false


chown -R $USER /tmp/ray/

```