// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./Interfaces/ICollSurplusPool.sol";
import "./Interfaces/ITroveManager.sol";
import "./Interfaces/IWETH.sol";
import "./Dependencies/ERDMath.sol";

contract CollSurplusPool is OwnableUpgradeable, ICollSurplusPool {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    string public constant NAME = "CollSurplusPool";

    address public borrowerOperationsAddress;
    address public troveManagerAddress;
    address public troveManagerLiquidationsAddress;
    address public troveManagerRedemptionsAddress;
    address public activePoolAddress;
    address public wethAddress;

    // Collateral surplus claimable by trove owners
    // mapping (address => uint[]) internal balances;
    struct Info {
        bool hasBalance;
        mapping(address => uint256) balance;
    }
    mapping(address => Info) internal balances;

    // --- Contract setters ---
    function initialize() public initializer {
        __Ownable_init();
    }

    function setAddresses(
        address _borrowerOperationsAddress,
        address _troveManagerAddress,
        address _troveManagerLiquidationsAddress,
        address _troveManagerRedemptionsAddress,
        address _activePoolAddress,
        address _wethAddress
    ) external override onlyOwner {
        _requireIsContract(_borrowerOperationsAddress);
        _requireIsContract(_troveManagerAddress);
        _requireIsContract(_troveManagerLiquidationsAddress);
        _requireIsContract(_troveManagerRedemptionsAddress);
        _requireIsContract(_activePoolAddress);
        _requireIsContract(_wethAddress);

        borrowerOperationsAddress = _borrowerOperationsAddress;
        troveManagerAddress = _troveManagerAddress;
        troveManagerLiquidationsAddress = _troveManagerLiquidationsAddress;
        troveManagerRedemptionsAddress = _troveManagerRedemptionsAddress;
        activePoolAddress = _activePoolAddress;
        wethAddress = _wethAddress;

        emit BorrowerOperationsAddressChanged(_borrowerOperationsAddress);
        emit TroveManagerAddressChanged(_troveManagerAddress);
        emit TroveManagerLiquidationsAddressChanged(
            _troveManagerLiquidationsAddress
        );
        emit TroveManagerRedemptionsAddressChanged(
            _troveManagerRedemptionsAddress
        );
        emit ActivePoolAddressChanged(_activePoolAddress);
        emit WETHAddressChanged(_wethAddress);
    }

    /* Returns the collateral state variable at ActivePool address. */
    function getTotalCollateral()
        public
        view
        override
        returns (
            uint256 total,
            address[] memory collaterals,
            uint256[] memory amounts
        )
    {
        collaterals = ITroveManager(troveManagerAddress).getCollateralSupport();
        uint256 collLen = collaterals.length;
        amounts = new uint256[](collLen);
        for (uint256 i = 0; i < collLen; ) {
            amounts[i] = IERC20Upgradeable(collaterals[i]).balanceOf(
                address(this)
            );
            total = total.add(amounts[i]);
            unchecked {
                i++;
            }
        }
    }

    function getCollateralAmount(
        address _collateral
    ) external view override returns (uint256) {
        return IERC20Upgradeable(_collateral).balanceOf(address(this));
    }

    function getCollateral(
        address _account,
        address _collateral
    ) external view override returns (uint256) {
        return balances[_account].balance[_collateral];
    }

    // --- Pool functionality ---

    function accountSurplus(
        address _account,
        uint256[] memory _amount
    ) external override {
        _requireCallerIsTMLorTMR();

        address[] memory collaterals = ITroveManager(troveManagerAddress)
            .getCollateralSupport();

        uint256 length = collaterals.length;
        for (uint256 i = 0; i < length; ) {
            address collateral = collaterals[i];
            uint256 amount = _amount[i];
            if (amount != 0) {
                Info storage info = balances[_account];
                info.hasBalance = true;
                info.balance[collateral] = info.balance[collateral].add(amount);
            }
            unchecked {
                i++;
            }
        }

        emit CollBalanceUpdated(_account, balances[_account].hasBalance);
    }

    function claimColl(address _account) external override {
        _requireCallerIsBorrowerOperations();
        address[] memory collaterals = ITroveManager(troveManagerAddress)
            .getCollateralSupport();
        uint256 length = collaterals.length;
        Info storage info = balances[_account];
        bool flag = info.hasBalance;
        require(flag, "CollSurplusPool: No collateral available to claim");
        info.hasBalance = false;
        uint256[] memory claimableColls = new uint256[](length);
        emit CollBalanceUpdated(_account, false);
        for (uint256 i = 0; i < length; ) {
            address collateral = collaterals[i];
            uint256 amount = info.balance[collateral];
            claimableColls[i] = amount;
            if (amount != 0) {
                info.balance[collateral] = 0;
                if (collateral != wethAddress) {
                    IERC20Upgradeable(collateral).transfer(_account, amount);
                } else {
                    IWETH(wethAddress).withdraw(amount);
                    (bool success, ) = _account.call{value: amount}("");
                    require(success, "CollSurplusPool: sending ETH failed");
                }
            }
            unchecked {
                i++;
            }
        }
        emit CollateralSent(_account, claimableColls);
    }

    // --- 'require' functions ---

    function _requireIsContract(address _contract) internal view {
        require(
            _contract.isContract(),
            "CollSurplusPool: Contract check error"
        );
    }

    function _requireCallerIsBorrowerOperations() internal view {
        require(
            msg.sender == borrowerOperationsAddress,
            "CollSurplusPool: Caller is not Borrower Operations"
        );
    }

    function _requireCallerIsTMLorTMR() internal view {
        require(
            msg.sender == troveManagerLiquidationsAddress ||
                msg.sender == troveManagerRedemptionsAddress,
            "CollSurplusPool: Caller is not TML nor TMR"
        );
    }

    function _requireCallerIsActivePool() internal view {
        require(
            msg.sender == activePoolAddress,
            "CollSurplusPool: Caller is not Active Pool"
        );
    }

    // --- Fallback function ---

    receive() external payable {}
}
