# Instructions for Google Cloud Shiny Server

*Author*: Timm Nawrocki, Alaska Center for Conservation Science

*Last Updated*: 2024-01-11

*Description*: This document contains instructions and commands for deploying a Shiny server on a Google Cloud virtual machine (vm). If preferred, all of the configuration steps can also be scripted using the Google Cloud SDK. Users should download and install the [Google Cloud SDK](https://cloud.google.com/sdk/) regardless because it is necessary for file uploads and downloads.

## 1. Configure project

Create a new project if necessary and enable API access for Google Cloud Compute Engine.

### Create a storage bucket for the project:

Create a new storage bucket if necessary. This example uses the "accs-shiny" bucket. Select "multiregional" and make the region the same as the region that your virtual machine will be in. If your virtual machines must be in multiple regions, it is not necessary to have a bucket for each region if you will just be uploading and downloading files between the two.

Use the "gsutil cp -r" command to copy data to and from the bucket. Example:

```
gsutil cp -r gs://accs-shiny/* ~/shiny/
```

The '*' is a wildcard. The target directory should already exist in the virtual machine or local machine. If the google bucket is the target, the bucket will create a new directory from the copy command.

### Configure a firewall rule to allow browser access for RStudio:

The firewall rule must be configured once per project. Navigate to VPC Network -> Firewall and create new firewall rule with the following features:

*Name*: rstudio-rule

*Description*: Allows online access to RStudio Server.

*Logs*: Off

*Network*: default

*Priority*: 1000

*Direction of traffic*: Ingress

*Action on match*: Allow

*Targets*: All instances in the network

*Source filter*: IPv4 ranges

*Source IP ranges*: 0.0.0.0/0

*Second source filter*: None

*Destination filter*: None

*Protocols/ports*: Specified protocols and ports
    Check "tcp" and enter "8787"

### Configure a firewall rule to allow browser access for Shiny:

The firewall rule must be configured once per project. Navigate to VPC Network -> Firewall and create a new firewall rule with the following features:

*Name*: shiny-rule

*Description*: Allows online access to Shiny server.

*Logs*: Off

*Network*: default

*Priority*: 1000

*Direction of traffic*: Ingress

*Action on match*: Allow

*Targets*: All instances in the network

*Source filter*: IPv4 ranges

*Source IP ranges*: 0.0.0.0/0

*Second source filter*: None

*Destination filter*: None

*Protocols/ports*: Specified protocols and ports
    Check "tcp" and enter "3838"

## 2. Configure a new vm instance

The following steps must be followed every time a new instance is provisioned. The first vm will serve as a image template for the additional vms. The software and data loaded on the template vm are exported as a custom disk image along with the operating system. Each additional instance can use the custom disk image rather than requiring independent software installation and data upload.

### Create a new instance with the following features:

After hitting the create button, the new instance will start automatically.

*Name*: accs_shiny

*Region*: us-west1 (Oregon) 

*Zone*: us-west1-b

*Machine Type*: 2 vCPUs (2 GB memory)

*Boot Disk*: Ubuntu 22.04 LTS

*Boot Disk Type*: Standard Persistent Disk

*Size (GB)*: 10

*Service Account*: Compute Engine default service account

*Access scopes*: Allow full access to all Cloud APIs

*Firewall*: Allow HTTP Traffic, Allow HTTPS traffic

### Reserve external static IP address

The vm has an ephemeral IP address, but this will not enable consistent access. To enable consistent access, you must associate an external static IP address with the vm. Navigate to VPC Network -> External IP Addresses. Click "Reserve a static address" and enter the following information.

*Name*: shiny-ip

*Description*: External static IP address for Shiny server.

*Network Service Tier*: Premium

*IP version*: IPv4

*Type*: Regional

*Region*: us-west1 (or the same region as the vm)

*Attach to*: {vm_name}

### Set up the system environment:

Launch the terminal in a browser window using ssh to accomplish the following steps. Update the system prior to installing software and then install necessary dependencies.

```
sudo apt-get update
sudo apt install -y build-essential
sudo apt-get -y install nginx
sudo apt install -y dirmngr gnupg apt-transport-https ca-certificates software-properties-common
sudo apt-get -y install libcurl4-gnutls-dev libxml2-dev libssl-dev
sudo apt install -y libgeos-dev libproj-dev libgdal-dev libudunits2-dev
sudo apt-get install gdebi-core
sudo apt-get update
```

Add the CRAN repository to the system sources list. The version referenced in the example below may need to be updated. The repository version should match the Ubuntu Linux LTS release version. The version below is for 22.04 LTS.

```
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo gpg --dearmor -o /usr/share/keyrings/r-project.gpg
echo "deb [signed-by=/usr/share/keyrings/r-project.gpg] https://cloud.r-project.org/bin/linux/ubuntu jammy-cran40/" | sudo tee -a /etc/apt/sources.list.d/r-project.list
sudo apt update
```

Install latest R release and check R version.

```
sudo apt-get -y install r-base
R --version
```

Install necessary R libraries globally. The "devtools" installation will require around 15 minutes.

```
sudo su - -c "R -e \"install.packages('devtools', repos='http://cran.rstudio.com/')\""
sudo su - -c "R -e \"install.packages('DT', repos='http://cran.rstudio.com/')\""
sudo su - -c "R -e \"install.packages('shiny', repos='http://cran.rstudio.com/')\""
sudo su - -c "R -e \"install.packages('rmarkdown', repos='http://cran.rstudio.com/')\""
sudo su - -c "R -e \"install.packages('tidyverse', repos='http://cran.rstudio.com/')\""
sudo su - -c "R -e \"install.packages('leaflet', repos='http://cran.rstudio.com/')\""
sudo su - -c "R -e \"install.packages('plotly', repos='http://cran.rstudio.com/')\""
sudo su - -c "R -e \"install.packages('shinythemes', repos='http://cran.rstudio.com/')\""
```

Install latest R Studio Server. The version may need to be updated from below.

```
wget https://download2.rstudio.org/server/jammy/amd64/rstudio-server-2023.12.0-369-amd64.deb
sudo gdebi rstudio-server-2023.12.0-369-amd64.deb
rm rstudio-server-2023.12.0-369-amd64.deb
```

Install latest Shiny Server. The version may need to be updated from below.

```
wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.21.1012-amd64.deb
sudo gdebi shiny-server-1.5.21.1012-amd64.deb
rm shiny-server-1.5.21.1012-amd64.deb
```

Once R Studio Server and Shiny Server are installed, they will automatically start running.

### Set up RStudio Server user and password:

Add a separate user for R Studio that will have a password separate from the Google authentication. Enter the password at the prompt. In this example, I used username "accs_rstudio".

```
sudo adduser accs_rstudio
```

Add the new user to the super user group.

```
sudo usermod -aG sudo accs_rstudio
```

The new username and password will serve as the login information for RStudio Server. All of the files accessible to RStudio must be added to the RStudio user. To switch user within the Ubuntu shell, enter the following command:

```
su accs_rstudio
```

To enable RStudio to have read and write access over the new user directory:

```
sudo chown -R accs_rstudio /home/accs_rstudio/
sudo chmod -R 770 /home/accs_rstudio/
```

When transferring files after transferring ownership, 'sudo' must precede the 'gsutil' call. Ownership does not need to be transferred back to the <username> user to transfer files to the Google Cloud Storage Bucket as long as 'sudo' is used.

### Set permissions for Shiny user:

Shiny apps are executed by a user called "shiny" in the directory "/srv/shiny-server". The permissions for the shiny server folder need to be enabled for all users.

```
sudo chmod -R a+rwx /srv/shiny-server/
```

### Download files to the virtual machine:

```
cd ~
mkdir ~/example
gsutil cp -r gs://beringia/example/* ~/example/
```

The vm instance is now configured and ready to run processes on R Studio Server.

### [Optional] Create a custom disk image from template vm:

Creating a custom disk image will allow additional vms to be created that are identical to the template including all files and installed software. This can save much time when creating clusters of vms.

1. Stop the vm
2. Select Compute Engine -> Images
3. Click 'Create Image'
4. Name the image
5. Leave 'Family' blank
6. Select the template vm as the 'Source disk'

Once the image creates successfully, other vm can be created using the custom image, obviating the need to install software and load files for each vm independently.

## 3. Access R Studio Server or Shiny

RStudio and Shiny will be running automatically once set up. They do not need manual start and stop. In a browser, navigate to http://<your_VM_IP>:8787/ for RStudio and http://<your_VM_IP>:3838/ for Shiny. Individual shiny apps can be loaded as http://<your_VM_IP>:3838/APP_NAME/

**IMPORTANT: When finished, the instance must be stopped to prevent being billed additional time**.

The instance can be stopped in the browser interface or by typing the following command into the Google Cloud console:

```
gcloud compute instances stop --zone=us-west1-b <instance_name>
```

**IMPORTANT: Release static ip address after instance is deleted to avoid being billed for unattached static ip.**

## 4. Assign domain name and replace port names

TBD: NGINX can be used to replace port names. Assign domain name & get security certificate. Enforce https.