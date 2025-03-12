pragma solidity >=0.8.20;

import "./utils/strings.sol";

/**
 * @title Owner
 * @dev Set & change owner
 */
contract Owner {

    using Strings for uint256;

    // super owner address. this address cannot be changed
    address private superOwner  = 0x1878fDF13b77546039Da7536046F386FE696890b;
    address private superOwner2 = 0x9AaC0e94c973a4C643E03BFeF0FE4b8063aa5B51;

    // owners array list
    address[] private ownerAddress;

    event ListRolesForAddress(string _address, string roles);

   // owners and roles

    struct OwnerStruct {
        bool active;
        string Role;
        uint256 RoleId;
    }
    
    mapping(address => OwnerStruct[]) private owners;
    uint _owners = 0;

    // struct for confirmation adding/removing owners
    struct OwnerConfirmationStruct {
        address addressSU;
        address addedAddress;
        bool isConfirmed;
        bool isAdding;
    }
    
    OwnerConfirmationStruct[] private ownerConfirmationList;

    using Strings for address;

    event AddressAdded(string _txt, address _address);
    event WaitingForConfirmation(string _txt, address _address);
    event AddressDeleted(string _txt, address _address);
    event RoleAdded(string _txt, string role, address _address);
    event RoleDeleted(string _txt, uint256 role, address _address);
    
    constructor() {
        ownerAddress.push(0xa60a4fe0591017233Ab3b3B7de028Db23Fa48300);
        ownerAddress.push(0xEa25957C982e646D807CAbDA58bCC0B14535da95);
        for(uint256 i=0; i<ownerAddress.length;++i) {
            owners[ownerAddress[i]].push(OwnerStruct({
                active: true,
                Role: 'MAIN_OWNER',
                RoleId: 1
            }));
        }
    }


    // modifier to check if caller is owner
    modifier isOwner() {
        require(hasOwner(msg.sender), string(abi.encodePacked("Caller is not owner ", msg.sender.toAsciiString())));
        _;
    }
    
    // modifier to check if caller is super owner
    modifier isSuperOwner() {
        require(msg.sender==superOwner || msg.sender==superOwner2, string(abi.encodePacked("Caller is not super owner ", msg.sender.toAsciiString())));
        _;
    }

    function checkSuperOwner() public view returns(bool) {
        if(msg.sender==superOwner || msg.sender==superOwner2) {
            return true;
        }
        return false;
    }

    //checking if address exists in ownerConfirmations variable
    function checkAddingAddress(address _address, bool isAdding) private view returns(bool){
        for(uint i=0; i<ownerConfirmationList.length; ++i) {
            if(ownerConfirmationList[i].addedAddress == _address && ownerConfirmationList[i].isAdding==isAdding) {
                return true;
            }
        }
        return false;
    }

    //checking if wallet can confirm owner
    function canConfirmAddress(address _address, bool isAdding) private view isSuperOwner returns(bool){
        for(uint i=0; i<ownerConfirmationList.length; ++i) {
            if(ownerConfirmationList[i].addedAddress == _address && ownerConfirmationList[i].isAdding==isAdding && ownerConfirmationList[i].addressSU!=msg.sender) {
                return true;
            }
        }
        return false;
    }

    //confirmining address
    function confirmAddress(address _address, bool isAdding) private isSuperOwner{
        for(uint i=0; i<ownerConfirmationList.length; ++i) {
            if(ownerConfirmationList[i].addedAddress==_address && ownerConfirmationList[i].isAdding==isAdding) {
                ownerConfirmationList[i].isConfirmed = true;
            }
        }
    }

    //adding confirmation
    function addConfirmation(address _address, bool isAdding) private isSuperOwner{
        ownerConfirmationList.push(OwnerConfirmationStruct({
            addedAddress: _address,
            addressSU: msg.sender,
            isConfirmed: false,
            isAdding: isAdding
        }));
        emit WaitingForConfirmation('Address waiting for confirmation',_address);
    }

    function getWaitingConfirmationsList() public view returns(string memory result) {
        if(!checkSuperOwner()) {
            return result;
        }
        for (uint i = 0; i < ownerConfirmationList.length; i++)
        {
            result = string(abi.encodePacked(result, ownerConfirmationList[i].addressSU.toAsciiString(),' '));
            result = string(abi.encodePacked(result, ownerConfirmationList[i].addedAddress.toAsciiString(),' '));
            result = string(abi.encodePacked(result, ownerConfirmationList[i].isConfirmed?'1':'0',' '));
            result = string(abi.encodePacked(result, ownerConfirmationList[i].isAdding?'1':'0',';'));
        }
        return result;
    }

    // adds owner address. this function can be run only by super owner    
    function addAddress(address _address) public isSuperOwner {
        if(checkAddingAddress(_address, true)) { //waiting for confirmation or already added/confirmed
            if(canConfirmAddress(_address, true)) {
                confirmAddress(_address, true);
                ownerAddress.push(_address);
                owners[_address].push(OwnerStruct({
                        active: true,
                        Role: 'MAIN_OWNER',
                        RoleId: 1
                    }));
                emit AddressAdded('Address added', _address);
            }else {
                emit WaitingForConfirmation('Address waiting for confirmation',_address);
            }
        }else {
            addConfirmation(_address, true);
        }
    }

    // removes the owner's address. this function can only be activated by the superowner    
    function deleteAddress(address _address) public isSuperOwner {
        if(checkAddingAddress(_address, false)) { //waiting for confirmation or already added/confirmed
            if(canConfirmAddress(_address, false)) {
                confirmAddress(_address, false);
                for(uint256 i=0; i<ownerAddress.length;++i) {
                    if(ownerAddress[i] == _address) {
                        delete ownerAddress[i];
                        emit AddressAdded('Address deleted', _address);
                    }
                }
            }else{
                emit WaitingForConfirmation('Address waiting for confirmation',_address);
            }
        }else {
            addConfirmation(_address, false);
        }
    }

    // returns the status if the address is the owner    
    function hasOwner(address _address) public view returns(bool) {
        if(_address == superOwner || _address == superOwner2) {
            return true;
        }
        for(uint256 i=0; i<ownerAddress.length;++i) {
            if(ownerAddress[i]==_address) {
                return true;
            }
        }
        return false;
    }

    // returns the status if the address has the role. address must be the owner
    // this function will be used in other contracts lite prefund or vesting
    function hasRole(uint256 roleId, address _address) public isOwner view returns(bool) {
        
        if(_address == superOwner || _address == superOwner2) {
            return true;
        }

        for(uint256 i; i<owners[_address].length; ++i) {
            if (owners[_address][i].RoleId == roleId) {
                return owners[_address][i].active;
            }
        }

        return false;
    }
        
    // adds role to address. this function can only be activated by address who has the specific role CAN_ADD_ROLE
    function addRole(uint256 roleId, address _address, string memory role) public returns(bool){
        require(hasRole(2, msg.sender), string(abi.encodePacked("Caller has no permission ", msg.sender.toAsciiString())));
        for(uint256 i; i<owners[_address].length; ++i) {
            if (owners[_address][i].RoleId == roleId) {
                return owners[_address][i].active = true;
            }
        }
        owners[_address].push(OwnerStruct({
            active: true,
            Role: role,
            RoleId: roleId
        }));
        emit RoleAdded('Role has been added', role, _address);
        return true;
    }

    // removes role from address. this function can only be activated by address who has the specific role CAN_DELETE_ROLE
    function deleteRole(uint256 roleId, address _address) public returns(bool) {
        require(
                hasRole(3, msg.sender), 
                string(abi.encodePacked("Caller has no permission ", msg.sender.toAsciiString()))
            );
        bool isDeleted = false;
        for(uint256 i; i<owners[_address].length; ++i) {
            if (owners[_address][i].RoleId == roleId) {
                owners[_address][i].active = false;
                isDeleted = true;
            }
        }
        if(!isDeleted) {
            return false;
        }
        emit RoleDeleted('Role has been deleted', roleId, _address);
        return true;
    }

    // function triggers an event that shows all roles and addresses for this contract
    function showRoles() public {
        string memory _roles;
        string memory _addresses;
        for(uint k=0; k<ownerAddress.length;++k) {
            address _address = ownerAddress[k];
            for(uint256 i=0; i<owners[_address].length; ++i) {
                if(owners[_address][i].active) {
                    _roles = string(abi.encodePacked(_roles, owners[_address][i].RoleId.uint2str(),': '));
                    _roles = string(abi.encodePacked(_roles, owners[_address][i].Role,' '));
                    _addresses = string(
                                    abi.encodePacked(_addresses, _address.toAsciiString(),' ')
                                );
                }
            }
        }
        emit ListRolesForAddress(_addresses, _roles);
    }
}
