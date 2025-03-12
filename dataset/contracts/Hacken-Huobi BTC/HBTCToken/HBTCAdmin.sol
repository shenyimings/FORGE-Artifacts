pragma solidity ^0.5.11;

import "./Container.sol";

contract HBTCAdmin is Container{

    bytes32 internal constant OWNERHASH = 0x02016836a56b71f0d02689e69e326f4f4c1b9057164ef592671cf0d37c8040c0;
    bytes32 internal constant OPERATORHASH = 0x46a52cf33029de9f84853745a87af28464c80bf0346df1b32e205fc73319f622;
    bytes32 internal constant PAUSERHASH = 0x0cc58340b26c619cd4edc70f833d3f4d9d26f3ae7d5ef2965f81fe5495049a4f;
    bytes32 internal constant STOREHASH = 0xe41d88711b08bdcd7556c5d2d24e0da6fa1f614cf2055f4d7e10206017cd1680;
    bytes32 internal constant LOGICHASH = 0x397bc5b97f629151e68146caedba62f10b47e426b38db589771a288c0861f182;
    uint256 internal constant MAXUSERNUM = 255;
    bytes32[] private classHashArray;

    uint256 internal ownerRequireNum;
    uint256 internal operatorRequireNum;

    event AdminChanged(string TaskType, string class, address oldAddress, address newAddress);
    event AdminRequiredNumChanged(string TaskType, string class, uint256 previousNum, uint256 requiredNum);
    event AdminTaskDropped(bytes32 taskHash);

    function initAdmin(address owner0, address owner1, address owner2) internal{
        addItemAddress(OWNERHASH, owner0);
        addItemAddress(OWNERHASH, owner1);
        addItemAddress(OWNERHASH, owner2);
        addItemAddress(LOGICHASH, address(0x0));
        addItemAddress(STOREHASH, address(0x1));

        classHashArray.push(OWNERHASH);
        classHashArray.push(OPERATORHASH);
        classHashArray.push(PAUSERHASH);
        classHashArray.push(STOREHASH);
        classHashArray.push(LOGICHASH);
        ownerRequireNum = 2;
        operatorRequireNum = 2;
    }

    function classHashExist(bytes32 aHash) private view returns(bool){
        for(uint256 i = 0; i < classHashArray.length; i++)
            if(classHashArray[i] == aHash) return true;
        return false;
    }
    function getAdminAddresses(string memory class) public view returns(address[] memory) {
        bytes32 classHash = getClassHash(class);
        return getItemAddresses(classHash);
    }
    function getOwnerRequiredNum() public view returns(uint256){
        return ownerRequireNum;
    }
    function getOperatorRequiredNum() public view returns(uint256){
        return operatorRequireNum;
    }

    function resetRequiredNum(string memory class, uint256 requiredNum)
        public onlyOwner returns(bool){
        bytes32 classHash = getClassHash(class);
        require((classHash == OPERATORHASH) || (classHash == OWNERHASH),"wrong class");
        if (classHash == OWNERHASH)
            require(requiredNum <= getItemAddressCount(OWNERHASH),"num larger than existed owners");

        bytes32 taskHash = keccak256(abi.encodePacked("resetRequiredNum", class, requiredNum));
        addItemAddress(taskHash, msg.sender);

        if(getItemAddressCount(taskHash) >= ownerRequireNum){
            removeItem(taskHash);
            uint256 previousNum = 0;
            if (classHash == OWNERHASH){
                previousNum = ownerRequireNum;
                ownerRequireNum = requiredNum;
            }
            else if(classHash == OPERATORHASH){
                previousNum = operatorRequireNum;
                operatorRequireNum = requiredNum;
            }else{
                revert("wrong class");
            }
            emit AdminRequiredNumChanged("resetRequiredNum", class, previousNum, requiredNum);
        }
        return true;
    }


    function modifyAddress(string memory class, address oldAddress, address newAddress)
        internal onlyOwner returns(bool){
        bytes32 classHash = getClassHash(class);
        require(!itemAddressExists(classHash,newAddress),"address existed already");
        require(itemAddressExists(classHash,oldAddress),"address not existed");
        bytes32 taskHash = keccak256(abi.encodePacked("modifyAddress", class, oldAddress, newAddress));
        addItemAddress(taskHash, msg.sender);
        if(getItemAddressCount(taskHash) >= ownerRequireNum){
            replaceItemAddress(classHash, oldAddress, newAddress);
            emit AdminChanged("modifyAddress", class, oldAddress, newAddress);
            removeItem(taskHash);
            return true;
        }
        return false;
    }

    function getClassHash(string memory class) private view returns (bytes32){
        bytes32 classHash = keccak256(abi.encodePacked(class));
        require(classHashExist(classHash), "invalid class");
        return classHash;
    }

    function dropAddress(string memory class, address oneAddress)
        public onlyOwner returns(bool){
        bytes32 classHash = getClassHash(class);
        require(classHash != STOREHASH && classHash != LOGICHASH, "wrong class");
        require(itemAddressExists(classHash, oneAddress), "no such address exist");

        if(classHash == OWNERHASH)
            require(getItemAddressCount(classHash) > ownerRequireNum, "insuffience addresses");

        bytes32 taskHash = keccak256(abi.encodePacked("dropAddress", class, oneAddress));
        addItemAddress(taskHash, msg.sender);
        if(getItemAddressCount(taskHash) >= ownerRequireNum){
            removeOneItemAddress(classHash, oneAddress);
            emit AdminChanged("dropAddress", class, oneAddress, oneAddress);
            removeItem(taskHash);
            return true;
        }
        return false;

    }

    function addAddress(string memory class, address oneAddress)
        public onlyOwner returns(bool){
        bytes32 classHash = getClassHash(class);
        require(classHash != STOREHASH && classHash != LOGICHASH, "wrong class");
        require(!itemAddressExists(classHash,oneAddress),"address existed already");

        bytes32 taskHash = keccak256(abi.encodePacked("addAddress", class, oneAddress));
        addItemAddress(taskHash, msg.sender);
        if(getItemAddressCount(taskHash) >= ownerRequireNum){
            addItemAddress(classHash, oneAddress);
            emit AdminChanged("addAddress", class, oneAddress, oneAddress);
            removeItem(taskHash);
            return true;
        }
        return false;
    }


    function dropTask(bytes32 taskHash)
    public onlyOwner returns (bool){
        removeItem(taskHash);
        emit AdminTaskDropped(taskHash);
        return true;
    }

    modifier onlyOwner() {
        require(itemAddressExists(OWNERHASH, msg.sender), "only use owner to call");
        _;
    }

}