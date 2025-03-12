// SPDX-License-Identifier: UNLICENSED
/*
$$$$$$$\            $$\       $$\       $$\   $$\           $$$$$$$$\ $$\
$$  __$$\           $$ |      $$ |      \__|  $$ |          $$  _____|\__|
$$ |  $$ | $$$$$$\  $$$$$$$\  $$$$$$$\  $$\ $$$$$$\         $$ |      $$\ $$$$$$$\   $$$$$$\  $$$$$$$\   $$$$$$$\  $$$$$$\
$$$$$$$  | \____$$\ $$  __$$\ $$  __$$\ $$ |\_$$  _|        $$$$$\    $$ |$$  __$$\  \____$$\ $$  __$$\ $$  _____|$$  __$$\
$$  __$$<  $$$$$$$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |          $$  __|   $$ |$$ |  $$ | $$$$$$$ |$$ |  $$ |$$ /      $$$$$$$$ |
$$ |  $$ |$$  __$$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |$$\       $$ |      $$ |$$ |  $$ |$$  __$$ |$$ |  $$ |$$ |      $$   ____|
$$ |  $$ |\$$$$$$$ |$$$$$$$  |$$$$$$$  |$$ |  \$$$$  |      $$ |      $$ |$$ |  $$ |\$$$$$$$ |$$ |  $$ |\$$$$$$$\ \$$$$$$$\
\__|  \__| \_______|\_______/ \_______/ \__|   \____/       \__|      \__|\__|  \__| \_______|\__|  \__| \_______| \_______|

RabbitFinance.io
*/

/**
 *Submitted for verification at BscScan.com on 2021-03-10
*/

// File: openzeppelin-solidity-2.3.0/contracts/ownership/Ownable.sol

pragma solidity ^0.6.12;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be aplied to your functions to restrict their use to
 * the owner.
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * > Note: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// File: contracts/PriceOracle.sol

pragma solidity ^0.6.12;

interface PriceOracle {
    /// @dev Returns Goblin（token0、token1） prices, multiplied by 1e18
    /// NOTE: (if you have 1 token0 how much you can sell it for token1)
    function getPrice(address goblin)
    external view
    returns (uint256 price, uint256 lastUpdate);
}

// File: contracts/GoblinPriceOracle.sol

pragma solidity ^0.6.12;



contract GoblinPriceOracle is Ownable, PriceOracle {
    event PriceUpdate(address indexed goblin, uint256 price);

    struct PriceData {
        uint192 price;
        uint64 lastUpdate;
    }

    /// @notice Public price data mapping storage.
    mapping (address => PriceData) public store;

    /// @dev Set the prices of the goblin(token0、token1). Must be called by the owner.
    function setPrices(
        address[] calldata goblins,
        uint256[] calldata prices
    )
    external
    onlyOwner
    {
        uint256 len = goblins.length;
        require(prices.length == len, "bad prices length");
        for (uint256 idx = 0; idx < len; idx++) {
            address goblin = goblins[idx];
            uint256 price = prices[idx];
            store[goblin] = PriceData({
            price: uint192(price),
            lastUpdate: uint64(now)
            });
            emit PriceUpdate(goblin, price);
        }
    }

    /// @dev Returns Goblin（token0、token1） prices, multiplied by 1e18
    /// NOTE: (if you have 1 token0 how much you can sell it for token1)
    function getPrice(address goblin)
    external override view
    returns (uint256 price, uint256 lastUpdate)
    {
        PriceData memory data = store[goblin];
        price = uint256(data.price);
        lastUpdate = uint256(data.lastUpdate);
        require(price != 0 && lastUpdate != 0, "bad price data");
        return (price, lastUpdate);
    }
}