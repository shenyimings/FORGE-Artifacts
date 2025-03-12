// SPDX-Identifier: MIT
pragma solidity 0.8.16;

import "./ISeawaterExecutors.sol";

import "./ISeawaterAMM.sol";

// slots to store proxy data in
// these are calculated as keccak()-1 to avoid collisions

/// @dev 0xb27456616f8c77c635d3551b8179f6887795e920c5c4421a6fa3c3c76fc90fa8
bytes32 constant EXECUTOR_SWAP_SLOT = bytes32(uint256(keccak256("seawater.impl.swap")) - 1);

/// @dev 0x70879b7e5737e63f52eca3402c644a487e49ffeb7d78b75e54b18301a4f376ac
bytes32 constant EXECUTOR_SWAP_PERMIT2_SLOT = bytes32(uint256(keccak256("seawater.impl.swap_permit2")) - 1);

/// @dev 0x031aae58aa658a4a607141f8a509c1b56789f013acaf58a8e12eb86456e099e4
bytes32 constant EXECUTOR_QUOTE_SLOT = bytes32(uint256(keccak256("seawater.impl.quote")) - 1);

/// @dev 0x75711a1f12071de4ad9b405fd0234f84fcd9d494050d3a5169de3ad4fd942476
bytes32 constant EXECUTOR_POSITION_SLOT = bytes32(uint256(keccak256("seawater.impl.position")) - 1);

/// @dev 0x81e9c7c70971b5eb969cec21a82e6deed42e7c6736e0e83ced66d72297d9f1d7
bytes32 constant EXECUTOR_UPDATE_POSITION_SLOT = bytes32(uint256(keccak256("seawater.impl.update_position")) - 1);

/// @dev 0x344c13190645d452a52856ca1efc42b3609893d92b93219c8820b76f3aa11288
bytes32 constant EXECUTOR_ADMIN_SLOT = bytes32(uint256(keccak256("seawater.impl.admin")) - 1);

/// @dev 0xa77145850668b2edbbe1c458388a99e3dca3d62b8335520225dc4d03b2e2bfe0
bytes32 constant EXECUTOR_FALLBACK_SLOT = bytes32(uint256(keccak256("seawater.impl.fallback")) - 1);

// @dev 0xdfd6b2a695a9a2448c8c317669015a93e35dd154c29d011b7d533ae1dcabc1d5
bytes32 constant PROXY_ADMIN_SLOT = bytes32(uint256(keccak256("seawater.role.proxy.admin")) - 1);

// seawater admin / nft admin are stored in normal storage slots

// arbitrary storage slot access code borrowed from openzeppelin
library StorageSlot {
    struct AddressSlot {
        address value;
    }
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }
}

contract SeawaterAMM is ISeawaterAMM {
    modifier onlyProxyAdmin {
        require(
            msg.sender == StorageSlot.getAddressSlot(PROXY_ADMIN_SLOT).value,
            "only proxy admin"
        );
        _;
    }

    /// @notice constructor function, sets proxy details and then forwards to the seawater initialiser
    /// @param _proxyAdmin the admin that can control proxy functions (change addresses)
    /// @param _seawaterAdmin the admin of the AMM
    /// @param _nftManager the account that can transfer position NFTs
    /// @param _executorSwap the deployed code for the swap executor
    /// @param _executorSwapPermit2 the deployed code for the swap_permit2 executor
    /// @param _executorQuote the deployed code for the quote executor
    /// @param _executorPosition the deployed code for the positions executor
    /// @param _executorAdmin the deployed code for the admin executor
    /// @param _executorFallback an address that functions not matching a specific executor get set to
    constructor(
        address _proxyAdmin,
        address _seawaterAdmin,
        address _nftManager,
        address _emergencyCouncil,
        ISeawaterExecutorSwap _executorSwap,
        ISeawaterExecutorSwapPermit2 _executorSwapPermit2,
        ISeawaterExecutorQuote _executorQuote,
        ISeawaterExecutorPosition _executorPosition,
        ISeawaterExecutorUpdatePosition _executorUpdatePosition,
        ISeawaterExecutorAdmin _executorAdmin,
        ISeawaterExecutorFallback _executorFallback
    ) {
        _setProxyAdmin(_proxyAdmin);
        _setProxies(
            _executorSwap,
            _executorSwapPermit2,
            _executorQuote,
            _executorPosition,
            _executorUpdatePosition,
            _executorAdmin,
            _executorFallback
        );

        (bool success, bytes memory data) = _getExecutorAdmin().delegatecall(abi.encodeCall(
            ISeawaterExecutorAdmin.ctor,
            (_seawaterAdmin, _nftManager, _emergencyCouncil)
        ));
        // the string() cast here is just for typechecking, `data` is essentially arbitrary
        require(success, string(data));
    }

    // proxy functions

    /// @notice updates the proxy admin. only usable by the proxy admin
    /// @param newAdmin the new proxy admin to set
    function updateProxyAdmin(address newAdmin) public onlyProxyAdmin {
        _setProxyAdmin(newAdmin);
    }

    /// @notice updates the addresses of the executors. only usable by the proxy admin
    /// @param executorSwap the address of the swap executor
    /// @param executorSwapPermit2 the deployed code for the swap_permit2 executor
    /// @param executorQuote the deployed code for the quote executor
    /// @param executorPosition the address of the position executor
    /// @param executorAdmin the address of the admin executor
    /// @param executorFallback the address of the fallback executor
    function updateExecutors(
        ISeawaterExecutorSwap executorSwap,
        ISeawaterExecutorSwapPermit2 executorSwapPermit2,
        ISeawaterExecutorQuote executorQuote,
        ISeawaterExecutorPosition executorPosition,
        ISeawaterExecutorUpdatePosition executorUpdatePosition,
        ISeawaterExecutorAdmin executorAdmin,
        ISeawaterExecutorFallback executorFallback
    ) public onlyProxyAdmin {
        _setProxies(executorSwap, executorSwapPermit2, executorQuote, executorPosition, executorUpdatePosition, executorAdmin, executorFallback);
    }

    // seawater delegates

    // call a function with the same name and calldata on another contract
    // this ends execution!
    // proxy implementation adapted from openzeppelin
    function directDelegate(address to) internal {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), to, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    // admin functions

    /// @inheritdoc ISeawaterExecutorAdminExposed
    function createPoolD650E2D0(
        address /* token */,
        uint256 /* sqrtPriceX96 */,
        uint32 /* fee */,
        uint8 /* tickSpacing */,
        uint128 /* maxLiquidityPerTick */
    ) external {
        directDelegate(_getExecutorAdmin());
    }

    /// @inheritdoc ISeawaterExecutorAdminExposed
    function collectProtocol7540FA9F(
        address /* pool */,
        uint128 /* amount0 */,
        uint128 /* amount1 */,
        address /* recipient */
    ) external returns (uint128, uint128) {
        directDelegate(_getExecutorAdmin());
    }

    /// @inheritdoc ISeawaterExecutorAdminExposed
    function enablePool579DA658(
        address /* pool */,
        bool /* enabled */
    ) external {
        directDelegate(_getExecutorAdmin());
    }

    /// @inheritdoc ISeawaterExecutorAdminExposed
    function authoriseEnabler5B17C274(
        address /* enabler */,
        bool /* enabled */
    ) external {
        directDelegate(_getExecutorAdmin());
    }

    /// @inheritdoc ISeawaterExecutorAdminExposed
    function setSqrtPriceFF4DB98C(address /* pool */, uint256 /* price */) external {
        directDelegate(_getExecutorAdmin());
    }

    /// @inheritdoc ISeawaterExecutorAdminExposed
    function updateNftManager9BDF41F6(address /* manager */) external {
        directDelegate(_getExecutorAdmin());
    }

    /// @inheritdoc ISeawaterExecutorAdminExposed
    function updateEmergencyCouncil7D0C1C58(address /* council */) external {
        directDelegate(_getExecutorAdmin());
    }

    // swap functions

    /// @inheritdoc ISeawaterExecutorSwap
    function swap904369BE(address /* pool */, bool /* zeroForOne */, int256 /* amount */, uint256 /* priceLimit */) external returns (int256, int256) {
        directDelegate(_getExecutorSwap());
    }

    /// @inheritdoc ISeawaterExecutorQuote
    function quote72E2ADE7(address /* pool */, bool /* zeroForOne */, int256 /* amount */, uint256 /* priceLimit */) external {
        directDelegate(_getExecutorQuote());
    }


    /// @inheritdoc ISeawaterExecutorQuote
    function quote2CD06B86E(address /* to */, address /* from */, uint256 /* amount */, uint256 /* minOut*/) external {
        directDelegate(_getExecutorQuote());
    }

    /// @inheritdoc ISeawaterExecutorSwapPermit2
    function swapPermit2EE84AD91(
        address /* pool */,
        bool /* zeroForOne */,
        int256 /* amount */,
        uint256 /* priceLimit */,
        uint256 /* nonce */,
        uint256 /* deadline */,
        uint256 /* maxAmount */,
        bytes memory /* sig */
    ) external returns (int256, int256) {
        directDelegate(_getExecutorSwapPermit2());
    }

    /// @inheritdoc ISeawaterExecutorSwap
    function swap2ExactIn41203F1D(address /* tokenA */, address /* tokenB */, uint256 /* amountIn */, uint256 /* minAmountOut */) external returns (uint256, uint256) {
        directDelegate(_getExecutorSwap());
    }

    /// @inheritdoc ISeawaterExecutorSwapPermit2
    function swap2ExactInPermit236B2FDD8(
        address /* from */,
        address /* to */,
        uint256 /* amount */,
        uint256 /* minOut */,
        uint256 /* nonce */,
        uint256 /* deadline */,
        bytes memory /* sig */
    ) external returns (uint256, uint256) {
        directDelegate(_getExecutorSwapPermit2());
    }

    /// @inheritdoc ISeawaterAMM
    function swapIn32502CA71(address token, uint256 amountIn, uint256 minOut) external returns (int256, int256) {
        (bool success, bytes memory data) = _getExecutorSwap().delegatecall(abi.encodeCall(
            ISeawaterExecutorSwap.swap904369BE,
            (
                token,
                true,
                int256(amountIn),
                type(uint256).max
            )
        ));
        require(success, string(data));

        (int256 swapAmountIn, int256 swapAmountOut) = abi.decode(data, (int256, int256));
        // this contract uses checked arithmetic, this negate can revert
        require(-swapAmountOut >= int256(minOut), "min out not reached!");
        return (swapAmountIn, swapAmountOut);
    }

    /// @inheritdoc ISeawaterAMM
    function swapInPermit2CEAAB576(address token, uint256 amountIn, uint256 minOut, uint256 nonce, uint256 deadline, uint256 maxAmount, bytes memory sig) external returns (int256, int256) {
        (bool success, bytes memory data) = _getExecutorSwapPermit2().delegatecall(abi.encodeCall(
            ISeawaterExecutorSwapPermit2.swapPermit2EE84AD91,
            (
                token,
                true,
                int256(amountIn),
                type(uint256).max,
                nonce,
                deadline,
                maxAmount,
                sig
            )
        ));
        require(success, string(data));

        (int256 swapAmountIn, int256 swapAmountOut) = abi.decode(data, (int256, int256));
        // this contract uses checked arithmetic, this negate can revert
        require(-swapAmountOut >= int256(minOut), "min out not reached!");
        return (swapAmountIn, swapAmountOut);
    }

    /// @inheritdoc ISeawaterAMM
    function swapOut5E08A399(address token, uint256 amountIn, uint256 minOut) external returns (int256, int256) {
        (bool success, bytes memory data) = _getExecutorSwap().delegatecall(abi.encodeCall(
            ISeawaterExecutorSwap.swap904369BE,
            (
                token,
                false,
                int256(amountIn),
                type(uint256).max
            )
        ));
        require(success, string(data));

        (int256 swapAmountIn, int256 swapAmountOut) = abi.decode(data, (int256, int256));
        require(swapAmountOut >= int256(minOut), "min out not reached!");
        return (swapAmountIn, swapAmountOut);
    }

    /// @inheritdoc ISeawaterAMM
    function swapOutPermit23273373B(address token, uint256 amountIn, uint256 minOut, uint256 nonce, uint256 deadline, uint256 maxAmount, bytes memory sig) external returns (int256, int256) {
        (bool success, bytes memory data) = _getExecutorSwapPermit2().delegatecall(abi.encodeCall(
            ISeawaterExecutorSwapPermit2.swapPermit2EE84AD91,
            (
                token,
                false,
                int256(amountIn),
                type(uint256).max,
                nonce,
                deadline,
                maxAmount,
                sig
            )
        ));
        require(success, string(data));

        (int256 swapAmountIn, int256 swapAmountOut) = abi.decode(data, (int256, int256));
        require(swapAmountOut >= int256(minOut), "min out not reached!");
        return (swapAmountIn, swapAmountOut);
    }

    // position functions

    /// @inheritdoc ISeawaterExecutorPosition
    function mintPositionBC5B086D(address /* token */, int32 /* lower */, int32 /* upper */) external returns (uint256 /* id */) {
        directDelegate(_getExecutorPosition());
    }

    /// @inheritdoc ISeawaterExecutorPosition
    function burnPositionAE401070(uint256 /* id */) external {
        directDelegate(_getExecutorPosition());
    }

    /// @inheritdoc ISeawaterExecutorPosition
    function positionOwnerD7878480(uint256 /* id */) external returns (address) {
        directDelegate(_getExecutorPosition());
    }

    // called by the position manager contract!!
    /// @inheritdoc ISeawaterExecutorPosition
    function transferPositionEEC7A3CD(
        uint256 /* id */,
        address /* from */,
        address /* to */
    ) external {
        directDelegate(_getExecutorPosition());
    }

    /// @inheritdoc ISeawaterExecutorPosition
    function positionBalance4F32C7DB(address /* user */) external returns (uint256) {
        directDelegate(_getExecutorPosition());
    }

    /// @inheritdoc ISeawaterExecutorPosition
    function positionLiquidity8D11C045(
        address /* pool */,
        uint256 /* id */
    ) external returns (uint128) {
        directDelegate(_getExecutorPosition());
    }

    /// @inheritdoc ISeawaterExecutorPosition
    function positionTickLower2F77CCE1(
        address /* pool */,
        uint256 /* id */
    ) external returns (int32) {
        directDelegate(_getExecutorPosition());
    }

    /// @inheritdoc ISeawaterExecutorPosition
    function positionTickUpper67FD55BA(
        address /* pool */,
        uint256 /* id */
    ) external returns (int32) {
        directDelegate(_getExecutorPosition());
    }

    /// @inheritdoc ISeawaterExecutorAdminExposed
    function sqrtPriceX967B8F5FC5(address /* pool */) external returns (uint256) {
        directDelegate(_getExecutorAdmin());
    }

    /// @inheritdoc ISeawaterExecutorAdminExposed
    function feesOwed22F28DBD(
        address /* pool */,
        uint256 /* position */
    ) external returns (uint128, uint128) {
        directDelegate(_getExecutorAdmin());
    }

    /// @inheritdoc ISeawaterExecutorAdminExposed
    function curTick181C6FD9(address /* pool */) external returns (int32) {
        directDelegate(_getExecutorAdmin());
    }

    /// @inheritdoc ISeawaterExecutorAdminExposed
    function tickSpacing653FE28F(address /* pool */) external returns (uint8) {
        directDelegate(_getExecutorAdmin());
    }

    /// @inheritdoc ISeawaterExecutorAdminExposed
    function feeBB3CF608(address /* pool */) external returns (uint32) {
        directDelegate(_getExecutorAdmin());
    }

    /// @inheritdoc ISeawaterExecutorAdminExposed
    function feeGrowthGlobal038B5665B(address /* pool */) external returns (uint256) {
        directDelegate(_getExecutorAdmin());
    }

    /// @inheritdoc ISeawaterExecutorAdminExposed
    function feeGrowthGlobal1A33A5A1B(address /*pool */) external returns (uint256) {
        directDelegate(_getExecutorAdmin());
    }

    /// @inheritdoc ISeawaterExecutorPosition
    function collectSingleTo6D76575F(
        address /* pool */,
        uint256 /* id */,
        address /* recipient */
    ) external returns (uint128, uint128) {
        directDelegate(_getExecutorPosition());
    }

    /// @inheritdoc ISeawaterExecutorPosition
    function collect7F21947C(
        address[] memory /* pools */,
        uint256[] memory /* ids */
    ) external returns (CollectResult[] memory) {
        directDelegate(_getExecutorPosition());
    }

    /// @inheritdoc ISeawaterExecutorUpdatePosition
    function updatePositionC7F1F740(
        address /* pool */,
        uint256 /* id */,
        int128 /* delta */
    ) external returns (int256, int256) {
        directDelegate(_getExecutorUpdatePosition());
    }

    /// @inheritdoc ISeawaterExecutorUpdatePosition
    function incrPositionC3AC7CAA(
        address /* pool */,
        uint256 /* id */,
        uint256 /* amount0Min */,
        uint256 /* amount1Min */,
        uint256 /* amount0Desired */,
        uint256 /* amount1Desired */
    ) external returns (uint256, uint256) {
        directDelegate(_getExecutorUpdatePosition());
    }

    /// @inheritdoc ISeawaterExecutorUpdatePosition
    function decrPosition09293696(
        uint256 /* id */,
        uint256 /* amount0Min */,
        uint256 /* amount1Min */,
        uint256 /* amount0Max */,
        uint256 /* amount1Max */
    ) external returns (uint256, uint256) {
        directDelegate(_getExecutorUpdatePosition());
    }

    /// @inheritdoc ISeawaterExecutorUpdatePosition
    function incrPositionPermit25468326E(
        address /* token */,
        uint256 /* id */,
        uint256 /* amount0Min */,
        uint256 /* amount1Min */,
        uint256 /* nonce0 */,
        uint256 /* deadline0 */,
        uint256 /* amount0Max */,
        bytes memory /* sig0 */,
        uint256 /* nonce1 */,
        uint256 /* deadline1 */,
        uint256 /* amount1Max */,
        bytes memory /* sig1 */
    ) external returns (uint256, uint256) {
        directDelegate(_getExecutorUpdatePosition());
    }

    // fallback!
    fallback() external {
        require(msg.data.length > 3);
        require(msg.data[0] == 0);
        // swaps
        if (uint8(msg.data[2]) == 0) directDelegate(_getExecutorSwap());
        // update positions
        else if (uint8(msg.data[2]) == 1) directDelegate(_getExecutorUpdatePosition());
        // positions
        else if (uint8(msg.data[2]) == 2) directDelegate(_getExecutorPosition());
        // admin
        else if (uint8(msg.data[2]) == 3) directDelegate(_getExecutorAdmin());
        // swap permit 2
        else if (uint8(msg.data[2]) == 4) directDelegate(_getExecutorSwapPermit2());
        // quotes
        else if (uint8(msg.data[2]) == 5) directDelegate(_getExecutorQuote());
        else directDelegate(_getExecutorFallback());
    }

    // internal functions

    // proxy storage manipulators

    function _getExecutorSwap() internal view returns (address) {
        return StorageSlot.getAddressSlot(EXECUTOR_SWAP_SLOT).value;
    }
    function _getExecutorSwapPermit2() internal view returns (address) {
        return StorageSlot.getAddressSlot(EXECUTOR_SWAP_PERMIT2_SLOT).value;
    }
    function _getExecutorQuote() internal view returns (address) {
        return StorageSlot.getAddressSlot(EXECUTOR_QUOTE_SLOT).value;
    }
    function _getExecutorPosition() internal view returns (address) {
        return StorageSlot.getAddressSlot(EXECUTOR_POSITION_SLOT).value;
    }
    function _getExecutorUpdatePosition() internal view returns (address) {
        return StorageSlot.getAddressSlot(EXECUTOR_UPDATE_POSITION_SLOT).value;
    }
    function _getExecutorAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(EXECUTOR_ADMIN_SLOT).value;
    }
    function _getExecutorFallback() internal view returns (address) {
        return StorageSlot.getAddressSlot(EXECUTOR_FALLBACK_SLOT).value;
    }

    function _setProxyAdmin(address newAdmin) internal {
        StorageSlot.getAddressSlot(PROXY_ADMIN_SLOT).value = newAdmin;
    }

    function _setProxies(
        ISeawaterExecutorSwap executorSwap,
        ISeawaterExecutorSwapPermit2 executorSwapPermit2,
        ISeawaterExecutorQuote executorQuote,
        ISeawaterExecutorPosition executorPosition,
        ISeawaterExecutorUpdatePosition executorUpdatePosition,
        ISeawaterExecutorAdmin executorAdmin,
        ISeawaterExecutorFallback executorFallback
    ) internal {
        StorageSlot.getAddressSlot(EXECUTOR_SWAP_SLOT).value = address(executorSwap);
        StorageSlot.getAddressSlot(EXECUTOR_SWAP_PERMIT2_SLOT).value = address(executorSwapPermit2);
        StorageSlot.getAddressSlot(EXECUTOR_QUOTE_SLOT).value = address(executorQuote);
        StorageSlot.getAddressSlot(EXECUTOR_POSITION_SLOT).value = address(executorPosition);
        StorageSlot.getAddressSlot(EXECUTOR_UPDATE_POSITION_SLOT).value = address(executorUpdatePosition);
        StorageSlot.getAddressSlot(EXECUTOR_ADMIN_SLOT).value = address(executorAdmin);
        StorageSlot.getAddressSlot(EXECUTOR_FALLBACK_SLOT).value = address(executorFallback);
    }
}
