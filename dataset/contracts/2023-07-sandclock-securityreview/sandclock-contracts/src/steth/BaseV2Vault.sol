// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {EnumerableMap} from "openzeppelin-contracts/utils/structs/EnumerableMap.sol";

import {ProtocolNotSupported, ProtocolInUse, ZeroAddress} from "../errors/scErrors.sol";
import {Constants as C} from "../lib/Constants.sol";
import {IVault} from "../interfaces/balancer/IVault.sol";
import {IFlashLoanRecipient} from "../interfaces/balancer/IFlashLoanRecipient.sol";
import {IAdapter} from "./IAdapter.sol";
import {PriceConverter} from "./PriceConverter.sol";
import {Swapper} from "./Swapper.sol";
import {sc4626} from "../sc4626.sol";

/**
 * @title BaseV2Vault
 * @notice Base vault contract for v2 vaults to that use multiple lending markets thru adapters.
 */
abstract contract BaseV2Vault is sc4626, IFlashLoanRecipient {
    using Address for address;
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    event SwapperUpdated(address indexed admin, address newSwapper);
    event ProtocolAdapterAdded(address indexed admin, uint256 adapterId, address adapter);
    event ProtocolAdapterRemoved(address indexed admin, uint256 adapterId);
    event RewardsClaimed(uint256 adapterId);
    event TokenSwapped(address token, uint256 amount, uint256 amountReceived);

    // Balancer vault for flashloans
    IVault public constant balancerVault = IVault(C.BALANCER_VAULT);

    // price converter contract
    PriceConverter public immutable priceConverter;

    // swapper contract for facilitating token swaps
    Swapper public swapper;

    // mapping of IDs to lending protocol adapter contracts
    EnumerableMap.UintToAddressMap internal protocolAdapters;

    constructor(
        address _admin,
        address _keeper,
        ERC20 _asset,
        PriceConverter _priceConverter,
        Swapper _swapper,
        string memory _name,
        string memory _symbol
    ) sc4626(_admin, _keeper, _asset, _name, _symbol) {
        _zeroAddressCheck(address(_priceConverter));
        _zeroAddressCheck(address(_swapper));

        priceConverter = _priceConverter;
        swapper = _swapper;
    }

    /**
     * @notice Set the swapper contract used for executing token swaps.
     * @param _newSwapper The new swapper contract.
     */
    function setSwapper(Swapper _newSwapper) external {
        _onlyAdmin();

        if (address(_newSwapper) == address(0)) revert ZeroAddress();

        swapper = _newSwapper;

        emit SwapperUpdated(msg.sender, address(_newSwapper));
    }

    /**
     * @notice Add a new protocol adapter to the vault.
     * @param _adapter The adapter to add.
     */
    function addAdapter(IAdapter _adapter) external {
        _onlyAdmin();

        uint256 id = _adapter.id();

        if (isSupported(id)) revert ProtocolInUse(id);

        protocolAdapters.set(id, address(_adapter));

        address(_adapter).functionDelegateCall(abi.encodeWithSelector(IAdapter.setApprovals.selector));

        emit ProtocolAdapterAdded(msg.sender, id, address(_adapter));
    }

    /**
     * @notice Remove a protocol adapter from the vault. Reverts if the adapter is in use unless _force is true.
     * @param _adapterId The ID of the adapter to remove.
     * @param _force Whether or not to force the removal of the adapter.
     */
    function removeAdapter(uint256 _adapterId, bool _force) external {
        _onlyAdmin();
        _isSupportedCheck(_adapterId);

        // check if protocol is being used
        if (!_force && IAdapter(protocolAdapters.get(_adapterId)).getCollateral(address(this)) > 0) {
            revert ProtocolInUse(_adapterId);
        }

        _adapterDelegateCall(_adapterId, abi.encodeWithSelector(IAdapter.revokeApprovals.selector));

        protocolAdapters.remove(_adapterId);

        emit ProtocolAdapterRemoved(msg.sender, _adapterId);
    }

    /**
     * @notice Check if a lending market adapter is supported/used.
     * @param _adapterId The ID of the lending market adapter.
     */
    function isSupported(uint256 _adapterId) public view returns (bool) {
        return protocolAdapters.contains(_adapterId);
    }

    /**
     * @notice Claim rewards from a lending market.
     * @param _adapterId The ID of the lending market adapter.
     * @param _callData The encoded data for the claimRewards function.
     */
    function claimRewards(uint256 _adapterId, bytes calldata _callData) external {
        _onlyKeeperOrFlashLoan();
        _isSupportedCheck(_adapterId);

        _adapterDelegateCall(_adapterId, abi.encodeWithSelector(IAdapter.claimRewards.selector, _callData));

        emit RewardsClaimed(_adapterId);
    }

    /**
     * @notice Sell any token for the "asset" token on 0x exchange.
     * @param _token The token to sell.
     * @param _amount The amount of tokens to sell.
     * @param _swapData The swap data for 0xrouter.
     * @param _assetAmountOutMin The minimum amount of "asset" token to receive for the swap.
     */
    function zeroExSwap(ERC20 _token, uint256 _amount, bytes calldata _swapData, uint256 _assetAmountOutMin) external {
        _onlyKeeperOrFlashLoan();

        bytes memory result = address(swapper).functionDelegateCall(
            abi.encodeWithSelector(Swapper.zeroExSwap.selector, _token, asset, _amount, _assetAmountOutMin, _swapData)
        );

        emit TokenSwapped(address(_token), _amount, abi.decode(result, (uint256)));
    }

    function _multiCall(bytes[] memory _callData) internal {
        for (uint256 i = 0; i < _callData.length; i++) {
            address(this).functionDelegateCall(_callData[i]);
        }
    }

    function _adapterDelegateCall(uint256 _adapterId, bytes memory _data) internal {
        protocolAdapters.get(_adapterId).functionDelegateCall(_data);
    }

    function _adapterDelegateCall(address _adapter, bytes memory _data) internal {
        _adapter.functionDelegateCall(_data);
    }

    function _isSupportedCheck(uint256 _adapterId) internal view {
        if (!isSupported(_adapterId)) revert ProtocolNotSupported(_adapterId);
    }

    function _zeroAddressCheck(address _address) internal pure {
        if (_address == address(0)) revert ZeroAddress();
    }
}
