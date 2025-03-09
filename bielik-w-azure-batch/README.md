

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

az sig image-version list --resource-group BIELIK_GALLERY --gallery-name bielikGallery --gallery-image-definition bielik-vm-image

---

cd ../batch
az provider register --namespace Microsoft.Batch

terraform init
terraform apply

```