// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./IStockToken.sol";

/// @title StockToken
/// @author
/// @dev    Represents Each Stock of Reflection Platform
contract StockToken is ERC20, Ownable, ReentrancyGuard, IStockToken {
    address private refWalletAddress;
    address private rusdAddress;

    /// @dev
    /// @param __name (string)  Name of the token
    /// @param __symbol (string)    Symbol of the token
    /// @param _refWalletAddress (address)  ref wallet address that will be calling the contracts
    /// @param _rusdAddress (address)  ref wallet address that will be calling the contracts
    constructor(
        string memory __name,
        string memory __symbol,
        address _refWalletAddress,
        address _rusdAddress
    ) ERC20(__name, __symbol) {
        require(_refWalletAddress != address(0), "Zero Ref Address");
        require(_rusdAddress != address(0), "Zero RUSD Address");
        refWalletAddress = _refWalletAddress;
        rusdAddress = _rusdAddress;
    }

    /// @dev    Modifying default decimals value
    /// @return  (uint8)
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @dev    Updating the ref wallet address
    /// @param _address (address)
    function setRefWalletAddress(address _address) external onlyOwner {
        require(_address != address(0), "Zero Ref Address");
        refWalletAddress = _address;
    }

    /// @dev    Updating the RUSD address
    /// @param _address (address)
    function setRusdAddress(address _address) external onlyOwner {
        require(_address != address(0), "Zero RUSD Address");
        rusdAddress = _address;
    }

    /// @dev    Access Modifier for only ref wallet calls
    modifier onlyRefWalletAddress() {
        require(msg.sender == refWalletAddress, "Only ref wallet");
        _;
    }

    /// @dev    Access Modifier for only ref wallet calls
    modifier onlyRusdAddress() {
        require(msg.sender == rusdAddress, "Only RUSD");
        _;
    }

    /// @dev    Mint function to mint the stock token
    /// @param to (address)
    /// @param _amount (uint256)
    function mint(address to, uint256 _amount)
        external
        override
        onlyRusdAddress
    {
        _mint(to, _amount);
    }

    /// @dev    Burn function to burn out Tokens
    /// @param from (address)
    /// @param _amount (uint256)
    function burn(address from, uint256 _amount)
        external
        override
        onlyRusdAddress
    {
        _burn(from, _amount);
    }

    /// @dev    Function for buying this token using BUSD
    /// @param userAddress (address)    buyer address
    /// @param stockTokenAmount (uint256)    amount to buy
    /// @param stableCoinAmount (uint256)     price in BUSD
    /// @param stableCoinAddress (address)  address of stablecoin to use
    function buy(
        address userAddress,
        uint256 stockTokenAmount,
        uint256 stableCoinAmount,
        address stableCoinAddress
    ) external nonReentrant onlyRefWalletAddress {
        // check busd.allowance(user,this) > rusdAmount ?: take user approval
        require(
            IERC20(stableCoinAddress).transferFrom(
                userAddress,
                refWalletAddress,
                stableCoinAmount
            ),
            "Transfer Failed"
        );
        _mint(userAddress, stockTokenAmount);
    }

    /// @dev    Function for selling this token and get RUSD back
    /// @param userAddress (address)    seller address
    /// @param stockTokenAmount (uint256)    amount to sell
    /// @param stableCoinAmount (uint256)     price in RUSD
    /// @param stableCoinAddress (address)  address of stablecoin to use
    function sell(
        address userAddress,
        uint256 stockTokenAmount,
        uint256 stableCoinAmount,
        address stableCoinAddress
    ) external nonReentrant onlyRefWalletAddress {
        _burn(userAddress, stockTokenAmount);
        // check rusd.allowance(ref,this) > stableCoinAmount ?: make ref approve
        require(
            IERC20(stableCoinAddress).transferFrom(
                refWalletAddress,
                userAddress,
                stableCoinAmount
            ),
            "Transfer Failed"
        );
    }

    receive() external payable {
        revert();
    }
}
