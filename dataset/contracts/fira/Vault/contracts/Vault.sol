// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Vault {
    mapping(address => bool) public keeper;
    mapping(address => bool) public mkeeper;
    mapping(uint256 => uint256) public meter;
    uint256 public Limit = 3000;
    address public Guard;
    bool public Update;
    struct Wall {
        address stable;
        uint256 amount;
    }

    mapping(address => Wall) public vaults;

    constructor(address[] memory keepers, address guard, bool update) {
        Update = update;
        Guard = guard;
        for (uint256 i = 0; i < keepers.length; i++) {
            keeper[keepers[i]] = true;
            mkeeper[keepers[i]] = true;
        }
    }

    function deposit(address token, address stable, uint256 amount) external {
        require(keeper[msg.sender], "Vault: not keeper");
        if (vaults[token].stable == address(0)) {
            vaults[token].stable = stable;
        }
        vaults[token].amount += amount;
    }

    function withdraw(address token, address to, uint256 amount) external {
        require(keeper[msg.sender], "Vault: not keeper");
        require(vaults[token].amount >= amount, "Vault: not enough");
        require(vaults[token].stable != address(0), "Vault: not exist");
        uint256 ds = block.timestamp / 1 days;
        require(
            meter[ds] + amount <=
                ((meter[ds] + vaults[token].amount) * Limit) / 10000,
            "Vault: limit"
        );
        meter[ds] += amount;
        vaults[token].amount -= amount;
        SafeERC20.safeTransfer(IERC20(vaults[token].stable), to, amount);
    }

    function getVault(address token) external view returns (address, uint256) {
        return (vaults[token].stable, vaults[token].amount);
    }

    function safe(address _keeper) external {
        require(msg.sender == Guard, "Vault: not guard");
        require(mkeeper[_keeper], "Vault: not keeper");
        keeper[_keeper] = !keeper[_keeper];
    }

    function setLimit(uint256 limit) external {
        require(msg.sender == Guard, "Vault: not guard");
        Limit = limit;
    }

    function updateKeeper(address _keeper, bool state) external {
        require(msg.sender == Guard, "Vault: not guard");
        require(Update, "Vault: not add");
        keeper[_keeper] = state;
        mkeeper[_keeper] = state;
    }

    function off() external {
        require(msg.sender == Guard, "Vault: not guard");
        Update = false;
    }
}
