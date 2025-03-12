// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../depositary/IDepositaryBalanceView.sol";
import "./IValidator.sol";

contract CollateralBalanceValidator is IValidator, Ownable {
    using SafeMath for uint256;

    /// @notice Accuracy of permissible imbalance.
    uint256 public constant PERMISSIBLE_DECIMALS = 2;

    /// @notice Address of stable token.
    ERC20 public stableToken;

    /// @notice Address of collateral.
    IDepositaryBalanceView public collateral;

    /// @notice Permissible imbalance of stable token total supply and collateral balance.
    uint256 public permissibleImbalance;

    /// @notice An event thats emitted when stable token address updated.
    event StableTokenUpdated(address newStableToken);

    /// @notice An event thats emitted when collateral address updated.
    event CollateralUpdated(address newCollateral);

    /// @notice An event thats emitted when permissible imbalance updated.
    event PermissibleImbalanceUpdated(uint256 newPermissibleImbalance);

    /**
     * @param _stableToken Address of stable token.
     * @param _collateral Address of collateral.
     * @param _permissibleImbalance Permissible imbalance of stable token total supply and collateral balance.
     */
    constructor(
        address _stableToken,
        address _collateral,
        uint256 _permissibleImbalance
    ) public {
        stableToken = ERC20(_stableToken);
        collateral = IDepositaryBalanceView(_collateral);
        permissibleImbalance = _permissibleImbalance;
    }

    /**
     * @param _stableToken New stable token address.
     */
    function changeStableToken(address _stableToken) external onlyOwner {
        require(_stableToken != address(0), "CollateralBalanceValidator::changeStableToken: invalid stable token address");

        stableToken = ERC20(_stableToken);
        emit StableTokenUpdated(_stableToken);
    }

    /**
     * @param _collateral New collateral address.
     */
    function changeCollateral(address _collateral) external onlyOwner {
        require(_collateral != address(0), "CollateralBalanceValidator::changeCollateral: invalid collateral address");

        collateral = IDepositaryBalanceView(_collateral);
        emit CollateralUpdated(_collateral);
    }

    /**
     * @param _permissibleImbalance New permissible imbalance value.
     */
    function changePermissibleImbalance(uint256 _permissibleImbalance) external onlyOwner {
        permissibleImbalance = _permissibleImbalance;
        emit PermissibleImbalanceUpdated(_permissibleImbalance);
    }

    function validate() external view override returns (bool) {
        uint256 stableTotalSupply = stableToken.totalSupply();
        uint256 stableTokenDecimals = stableToken.decimals();
        uint256 collateralBalance = collateral.balance();
        uint256 collateralDecimals = collateral.decimals();

        if (stableTokenDecimals > collateralDecimals) {
            collateralBalance = collateralBalance.mul(10**(stableTokenDecimals - collateralDecimals));
        } else if (collateralDecimals > stableTokenDecimals) {
            stableTotalSupply = stableTotalSupply.mul(10**(collateralDecimals - stableTokenDecimals));
        }

        return collateralBalance.mul(10**PERMISSIBLE_DECIMALS).div(stableTotalSupply).add(permissibleImbalance) >= 100;
    }
}
