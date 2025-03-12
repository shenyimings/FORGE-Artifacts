pragma solidity 0.8;


import "./MedPingToken.sol"; 
import "@openzeppelin/contracts/access/Ownable.sol";

contract MedPingInvestorsVault is Ownable{
    MedPingToken _token;
    address _operator;

    struct VaultStruct {
        address _beneficiary;
        uint256 _balanceDue;
        uint256 _dueBy;
    }
    modifier onlyOperator {
        require(msg.sender == _operator, "You can not use this vault");
        _;
    }
    mapping(uint256 => VaultStruct) public VaultStructs; // This could be a mapping by address, but these numbered lockBoxes support possibility of multiple tranches per address
    mapping(address => uint256[]) public VaultKeys; 

    event LogVaultDeposit(address sender, uint256 amount, uint256 dueBy);   
    event LogVaultWithdrawal(address receiver, uint256 amount);

    constructor(MedPingToken token) Ownable() {
        _token = token;
    }

    function getOperator() public view returns (address){
        return _operator;
    }
    function setOperator(address operator) public onlyOwner returns (bool){
          _operator = operator;
          return true;
    }
    
    function createVaultKey(address beneficiary, uint identifier) internal view returns (uint256) {
         uint arrLen = VaultKeys[beneficiary].length;
         uint enc = arrLen * block.timestamp + identifier;
        return uint256( keccak256( abi.encodePacked(enc, block.difficulty)));
    }
    function getVaultKeys(address _beneficiary) public view returns (uint256[] memory) {
        return VaultKeys[_beneficiary];
    }

    function getVaultRecord(uint vaultKey) public view returns (address,uint,uint){
        VaultStruct storage v = VaultStructs[vaultKey];
        return (v._beneficiary,v._balanceDue,v._dueBy);
    }

    function recordShareToVault(address beneficiary, uint256 amount, uint256 dueBy,uint identifier) onlyOperator public returns(uint vaultKey) {
        uint key = createVaultKey(beneficiary,identifier);
        VaultStruct memory vault;
        vault._beneficiary = beneficiary;
        vault._balanceDue = amount;
        vault._dueBy = dueBy;
        VaultStructs[key] = vault;
        VaultKeys[beneficiary].push(key);
        emit LogVaultDeposit(msg.sender, amount, dueBy);
        return key;
    }

    function withdrawFromVault(uint vaultKey) public returns(bool success) {
        VaultStruct storage v = VaultStructs[vaultKey];
        require(v._beneficiary == msg.sender);
        require(v._dueBy <= block.timestamp);
        uint256 amount = v._balanceDue;
        v._balanceDue = 0;
        emit LogVaultWithdrawal(msg.sender, amount);
        require(_token.transfer(msg.sender, amount));
        return true;
    }    
}