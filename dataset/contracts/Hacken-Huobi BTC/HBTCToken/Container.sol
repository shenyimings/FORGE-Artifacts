pragma solidity ^0.5.11;

contract Container{
    struct Item{
        uint256 itemType;
        uint256 status;
        address[] addresses;
    }
    uint256 MaxItemAdressNum = 255;

    mapping (bytes32 => Item) private container;

    function itemAddressExists(bytes32 id, address oneAddress) internal view returns(bool){
        for(uint256 i = 0; i < container[id].addresses.length; i++){
            if(container[id].addresses[i] == oneAddress)
                return true;
        }
        return false;
    }
    function getItemAddresses(bytes32 id) internal view returns(address[] memory){
        return container[id].addresses;
    }

    function getItemInfo(bytes32 id) internal view returns(uint256, uint256, uint256){
        return (container[id].itemType, container[id].status, container[id].addresses.length);
    }

    function getItemAddressCount(bytes32 id) internal view returns(uint256){
        return container[id].addresses.length;
    }

    function setItemInfo(bytes32 id, uint256 itemType, uint256 status) internal{
        container[id].itemType = itemType;
        container[id].status = status;
    }

    function addItemAddress(bytes32 id, address oneAddress) internal{
        require(!itemAddressExists(id, oneAddress), "dup address added");
        require(container[id].addresses.length < MaxItemAdressNum, "too many addresses");
        container[id].addresses.push(oneAddress);
    }
    function removeItemAddresses(bytes32 id) internal{
        container[id].addresses.length = 0;
    }

    function removeOneItemAddress(bytes32 id, address oneAddress) internal{
        for(uint256 i = 0; i < container[id].addresses.length; i++){
            if(container[id].addresses[i] == oneAddress){
                container[id].addresses[i] = container[id].addresses[container[id].addresses.length - 1];
                container[id].addresses.length--;
                return;
            }
        }
        revert("not exist address");
    }

    function removeItem(bytes32 id) internal{
        delete container[id];
    }

    function replaceItemAddress(bytes32 id, address oneAddress, address anotherAddress) internal{
        require(!itemAddressExists(id,anotherAddress),"dup address added");
        for(uint256 i = 0; i < container[id].addresses.length; i++){
            if(container[id].addresses[i] == oneAddress){
                container[id].addresses[i] = anotherAddress;
                return;
            }
        }
        revert("not exist address");
    }
}