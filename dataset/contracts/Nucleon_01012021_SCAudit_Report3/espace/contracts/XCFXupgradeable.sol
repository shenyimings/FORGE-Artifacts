//SPDX-License-Identifier: BUSL-1.1
// Licensor:            X-Dao.
// Licensed Work:       NUCLEON 1.0

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract XCFXupgradeable is ERC20, Initializable {
    // ======================== configs =========================
    ERC20 token;
    address owner;
    mapping(address=>bool) mainMinter;
    uint unlocked=1;
    string  _name = "X Nucleon CFX";
    string  _symbol = "xCFX";
    // ======================== Methods =========================
    modifier onlyMinter() {
        require(mainMinter[msg.sender], "MinterRole: caller does not have the Minter role or above");
        _;
    }
    modifier onlyOwner() {
        require(msg.sender==owner, "Owner Role: caller does not have the Owner role or above");
        _;
    }
    modifier lock() {
        require(unlocked==1, "temp locked, wait a moment");
        unlocked = 0;
        _;
        unlocked = 1;
    }
    // ======================== constructor =========================
    constructor() ERC20("X nucleon CFX", "xCFX") {
        owner = msg.sender;
    }
    function initialize(ERC20 _token) public initializer {
        token = _token;
        owner = msg.sender;
        unlocked = 1;
        _name = "X nucleon CFX";
        _symbol = "xCFX";
    }
    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    // ======================== Owner function =========================
    function addMinter(address _minter) public onlyOwner(){
        mainMinter[_minter] = true;
    }
    function removeMinter(address _minter) public onlyOwner(){
        mainMinter[_minter] = false;
    }
    // ======================== Minter function =========================
    function addTokens(address _account, uint _value) external lock onlyMinter(){
        require(_value>0,"Con't add 0");
        //require( isContract(msg.sender) ,"msg.sender must be a contract");
        _mint(_account, _value);
    }
    function burnTokens(address _account, uint _value) external lock onlyMinter(){
        require(_value > 0,"Con't burn 0");
        require(_value <= balanceOf(_account),"Must < account balance");
        //require( isContract(msg.sender) ,"msg.sender must be a contract");
        _burn(_account, _value);
    }
    // ======================== require need function =========================
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.
        return account.code.length > 0;
    }
    

}

