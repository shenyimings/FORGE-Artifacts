pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract FaucetToken is ERC20, AccessControl {
    address internal initializer;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    bool public isEnabledFaucet;


    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC20("FaucetToken", "FaucetToken") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        initializer = msg.sender;
    }
    function initialize(string memory name_, string memory symbol_, uint8 decimals_) external {
        require(initializer == msg.sender);

        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        initializer = address(0);
        _mint(msg.sender, 100000 * (10 ** decimals()));

    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }


    function faucet() external {
        require(isEnabledFaucet || hasRole(MINTER_ROLE, msg.sender), "Can not faucet");
        _mint(msg.sender, 200 * (10 ** decimals()));
    }

    function mint(address to, uint256 value) external onlyRole(MINTER_ROLE) {
        _mint(to, value);
    }

    function flipEnabledFaucet() external onlyRole(MINTER_ROLE) {
        isEnabledFaucet = !isEnabledFaucet;
    }

    function burn(uint256 value) external onlyRole(MINTER_ROLE) {
        _burn(msg.sender, value);
    }
}