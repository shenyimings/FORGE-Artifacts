// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./IStockToken.sol";

contract RUSD is ERC20, Ownable, ReentrancyGuard {
    address private refWalletAddress;

    /// @dev    Constructor
    /// @param _refWalletAddress (address)  ref wallet address that will be calling the contracts
    constructor(address _refWalletAddress) ERC20("Reflection USD Stablecoin", "RUSD") {
        require(_refWalletAddress != address(0), "Zero Ref Address");
        refWalletAddress = _refWalletAddress;
    }

    /// @dev    Updating the ref wallet address
    /// @param _refWalletAddress (address)
    function setRefWalletAddress(address _refWalletAddress) external onlyOwner {
        require(_refWalletAddress != address(0), "Zero Ref Address");
        refWalletAddress = _refWalletAddress;
    }

    /// @dev    Access Modifier for only ref wallet calls
    modifier onlyRefWalletAddress() {
        require(msg.sender == refWalletAddress, "Only ref wallet");
        _;
    }

    /// @dev    Mint function if there's not enough RUSD supply
    /// @param to (address)
    /// @param _amount (uint256)
    function mint(address to, uint256 _amount) external onlyRefWalletAddress {
        _mint(to, _amount);
    }

    /// @dev    Burn function to burn out Tokens
    /// @param from (address)
    /// @param _amount (uint256)
    function burn(address from, uint256 _amount) external onlyRefWalletAddress {
        _burn(from, _amount);
    }

    /// @dev    Modifying default decimals to 6
    /// @return  (uint8)
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @dev    function for buying stock token
    /// @param _userAddress (address)
    /// @param _stableCoinAddress (address)
    /// @param _stockTokenAddress (address)
    /// @param _stableCoinAmount (uint256)
    /// @param _stockTokenAmount (uint256)
    function buyStock(
        address _userAddress,
        address _stableCoinAddress,
        address _stockTokenAddress,
        uint256 _stableCoinAmount,
        uint256 _stockTokenAmount
    ) external nonReentrant onlyRefWalletAddress {
        if (_stableCoinAddress == address(this)) {
            _burn(_userAddress, _stableCoinAmount);
        } else {
            require(
                IERC20(_stableCoinAddress).transferFrom(
                    _userAddress,
                    refWalletAddress,
                    _stableCoinAmount
                ),
                "Transfer Failed"
            );
        }
        IStockToken(_stockTokenAddress).mint(_userAddress, _stockTokenAmount);
    }

    /// @dev    function for selling stock token
    /// @param _userAddress (address)
    /// @param _stableCoinAddress (address)
    /// @param _stockTokenAddress (address)
    /// @param _stableCoinAmount (uint256)
    /// @param _stockTokenAmount (uint256)
    function sellStock(
        address _userAddress,
        address _stableCoinAddress,
        address _stockTokenAddress,
        uint256 _stableCoinAmount,
        uint256 _stockTokenAmount
    ) external nonReentrant onlyRefWalletAddress {
        if (_stableCoinAddress == address(this)) {
            _mint(_userAddress, _stableCoinAmount);
        } else {
            require(
                IERC20(_stableCoinAddress).transferFrom(
                    refWalletAddress,
                    _userAddress,
                    _stableCoinAmount
                ),
                "Transfer Failed"
            );
        }
        IStockToken(_stockTokenAddress).burn(_userAddress, _stockTokenAmount);
    }

    /// @dev    function for redeeming StableCoin to users for RUSD
    /// @param _userAddress (address)
    /// @param _stableCoinAddress (address)
    /// @param _amount (uint256)
    function redeemFor(
        address _userAddress,
        address _stableCoinAddress,
        uint256 _amount
    ) external nonReentrant onlyRefWalletAddress {
        // check stable.allowance(ref,rusd) >  ?: make ref approve
        _burn(_userAddress, _amount);
        require(
            IERC20(_stableCoinAddress).transferFrom(
                refWalletAddress,
                _userAddress,
                _amount
            ),
            "Transfer Failed"
        );
    }

    /// @dev    function for buying RUSD for StableCoin
    /// @param _userAddress (address)
    /// @param _stableCoinAddress (address)
    /// @param _amount (uint256)
    function buyRusd(
        address _userAddress,
        address _stableCoinAddress,
        uint256 _amount
    ) external nonReentrant onlyRefWalletAddress {
        require(
            IERC20(_stableCoinAddress).transferFrom(
                _userAddress,
                refWalletAddress,
                _amount
            ),
            "Transfer Failed"
        );
        _mint(_userAddress, _amount);
    }

    receive() external payable {
        revert();
    }
}
