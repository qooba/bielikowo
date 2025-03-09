import ray
import torch

ray.init(address="auto")

@ray.remote(num_gpus=1)
def llm_inference():
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Running task on {device}...")

    # Example GPU computation
    tensor = torch.rand(1000, 1000).to(device)
    result = torch.matmul(tensor, tensor)

    return f"Computation completed on {device}!"

future = llm_inference.remote()
print(ray.get(future))