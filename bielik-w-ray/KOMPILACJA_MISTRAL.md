# KOMPILACJA MISTRAL.RS

## Instalujemy rust i potrzene biblioteki
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

export PATH=$HOME/.local/bin:$PATH
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="/usr/local/cuda-12/bin:$PATH"

pip3 install maturin
pip3 install patchelf
```

## Klonujemy repo

```bash
git clone https://github.com/EricLBuehler/mistral.rs.git
cd mistral.rs
```

W pliku `Cargo.toml` podmieniamy `features` bilioteki `pyo3`
```bash
pyo3 = { version = "0.22.4", features = ["full", "extension-module", "either","experimental-async", "abi3", "abi3-py38", "anyhow"  ] }
```

## Kompilujemy
```bash
cd ./mistralrs-pyo3/
maturin build --release --features cuda  --compatibility manylinux2014 --skip-auditwheel
```