# rke2_node_gather_state
RKE2 Node State artifacts gather script - for offline CLuster Debugging

Instructions: 

    mkdir -p ~/.rke2/bin 
    cd -p ~/.rke2/bin 
    git clone <repository>.git
    cd rke2_node_gather_state

  #--- CLuster Built from Docker Private Repository (AirGap) node 1 ---#
  
  . ./rke2_node_gather_state.sh private 2.5.11 1
  
  scp -rp azureuser@<AZURE_HOST>:/tmp/1.2.5.11-private-files/1.2.5.11-private-files.tar.gz .
  

  
