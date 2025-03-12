// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IInitializerSender.sol";
import "./interfaces/IClientReceiverContract.sol";
import "./base/AsterizmEnv.sol";
import "./libs/AddressLib.sol";
import "./libs/UintLib.sol";
import "./libs/AsterizmHashLib.sol";

abstract contract AsterizmClient is Ownable, ReentrancyGuard, IClientReceiverContract, AsterizmEnv {

    using AddressLib for address;
    using UintLib for uint;
    using AsterizmHashLib for bytes;

    /// Set initializer event
    /// @param _initializerAddress address  Initializer address
    event SetInitializerEvent(address _initializerAddress);

    /// Set local chain id event
    /// @param _localChainId uint64
    event SetLocalChainIdEvent(uint64 _localChainId);

    /// Initiate transfer event (for client server logic)
    /// @param _dstChainId uint64  Destination chein ID
    /// @param _dstAddress uint  Destination address
    /// @param _txId uint  Transaction ID
    /// @param _transferHash bytes32  Transfer hash
    /// @param _payload bytes  Payload
    event InitiateTransferEvent(uint64 _dstChainId, uint _dstAddress, uint _txId, bytes32 _transferHash, bytes _payload);

    /// Payload receive event (for client server logic)
    /// @param _srcChainId uint64  Source chain ID
    /// @param _srcAddress uint  Source address
    /// @param _nonce uint  Transaction nonce
    /// @param _txId uint  Transfer ID
    /// @param _transferHash bytes32  Transaction hash
    /// @param _payload bytes  Payload
    event PayloadReceivedEvent(uint64 _srcChainId, uint _srcAddress, uint _nonce, uint _txId, bytes32 _transferHash, bytes _payload);

    /// Add trusted address event
    /// @param _chainId uint64  Chain ID
    /// @param _address uint  Trusted address
    event AddTrustedAddressEvent(uint64 _chainId, uint _address);

    /// Remove trusted address event
    /// @param _chainId uint64  Chain ID
    /// @param _address uint  Trusted address
    event RemoveTrustedAddressEvent(uint64 _chainId, uint _address);

    /// Set use encryption flag
    /// @param _flag bool  Use encryption flag
    event SetUseEncryptionEvent(bool _flag);

    /// Set use force order flag event
    /// @param _flag bool  Use force order flag
    event SetUseForceOrderEvent(bool _flag);

    /// Set disable hash validation flag event
    /// @param _flag bool  Use force order flag
    event SetDisableHashValidationEvent(bool _flag);

    /// Resend Asterizm transfer event
    /// @param _transferHash bytes32  Transfer hash
    /// @param _feeAmount uint  Additional fee amount
    event ResendAsterizmTransferEvent(bytes32 _transferHash, uint _feeAmount);

    struct AsterizmTransfer {
        bool successReceive;
        bool successExecute;
    }

    struct AsterizmChain {
        bool exists;
        uint trustedAddress;
        uint8 chainType;
    }

    IInitializerSender private initializerLib;
    mapping(uint64 => AsterizmChain) private trustedAddresses;
    mapping(bytes32 => AsterizmTransfer) private inboundTransfers;
    mapping(bytes32 => AsterizmTransfer) private outboundTransfers;
    bool private useForceOrder;
    bool private disableHashValidation;
    uint private txId;
    uint64 private localChainId;

    constructor(IInitializerSender _initializerLib, bool _useForceOrder, bool _disableHashValidation) {
        _setInitializer(_initializerLib);
        _setLocalChainId(initializerLib.getLocalChainId());
        _setUseForceOrder(_useForceOrder);
        _setDisableHashValidation(_disableHashValidation);
        addTrustedAddress(localChainId, address(this).toUint());
    }

    /// Only initializer modifier
    modifier onlyInitializer {
        require(msg.sender == address(initializerLib), "AsterizmClient: only initializer");
        _;
    }

    /// Only owner or initializer modifier
    modifier onlyOwnerOrInitializer {
        require(msg.sender == owner() || msg.sender == address(initializerLib), "AsterizmClient: only owner or initializer");
        _;
    }

    /// Only trusted address modifier
    /// You must add trusted addresses in production networks!
    modifier onlyTrustedAddress(uint64 _chainId, uint _address) {
        require(trustedAddresses[_chainId].trustedAddress == _address, "AsterizmClient: wrong source address");
        _;
    }

    /// Only trusted trarnsfer modifier
    /// Validate transfer hash on initializer
    /// Use this modifier for validate transfer by hash
    /// @param _transferHash bytes32  Transfer hash
    modifier onlyTrustedTransfer(bytes32 _transferHash) {
        require(initializerLib.validIncomeTransferHash(_transferHash), "AsterizmClient: transfer hash is invalid");
        _;
    }

    /// Only received transfer modifier
    /// @param _transferHash bytes32  Transfer hash
    modifier onlyReceivedTransfer(bytes32 _transferHash) {
        require(inboundTransfers[_transferHash].successReceive, "AsterizmClient: transfer not received");
        _;
    }

    /// Only non-executed transfer modifier
    /// @param _transferHash bytes32  Transfer hash
    modifier onlyNonExecuted(bytes32 _transferHash) {
        require(!inboundTransfers[_transferHash].successExecute, "AsterizmClient: transfer executed already");
        _;
    }

    /// Only exists outbound transfer modifier
    /// @param _transferHash bytes32  Transfer hash
    modifier onlyExistsOutboundTransfer(bytes32 _transferHash) {
        require(outboundTransfers[_transferHash].successReceive, "AsterizmClient: outbound transfer not exists");
        _;
    }

    /// Only not executed outbound transfer modifier
    /// @param _transferHash bytes32  Transfer hash
    modifier onlyNotExecutedOutboundTransfer(bytes32 _transferHash) {
        require(!outboundTransfers[_transferHash].successExecute, "AsterizmClient: outbound transfer executed already");
        _;
    }

    /// Only executed outbound transfer modifier
    /// @param _transferHash bytes32  Transfer hash
    modifier onlyExecutedOutboundTransfer(bytes32 _transferHash) {
        require(outboundTransfers[_transferHash].successExecute, "AsterizmClient: outbound transfer not executed");
        _;
    }

    /// Only nvalid transfer hash modifier
    /// @param _dto ClAsterizmReceiveRequestDto  Transfer data
    modifier onlyValidTransferHash(ClAsterizmReceiveRequestDto memory _dto) {
        if (!disableHashValidation) {
            require(
                _validTransferHash(_dto.srcChainId, _dto.srcAddress, _dto.dstChainId, _dto.dstAddress, _dto.txId, _dto.payload, _dto.transferHash),
                "AsterizmClient: transfer hash is invalid"
            );
        }
        _;
    }

    /** Internal logic */

    /// Set initizlizer library
    /// _initializerLib IInitializerSender  Initializer library
    function _setInitializer(IInitializerSender _initializerLib) private {
        initializerLib = _initializerLib;
        emit SetInitializerEvent(address(_initializerLib));
    }

    /// Set local chain id library
    /// _localChainId uint64
    function _setLocalChainId(uint64 _localChainId) private {
        localChainId = _localChainId;
        emit SetLocalChainIdEvent(_localChainId);
    }

    /// Set use force order flag
    /// _flag bool  Use force order flag
    function _setUseForceOrder(bool _flag) private {
        useForceOrder = _flag;
        emit SetUseForceOrderEvent(_flag);
    }

    /// Set disable hash validation flag
    /// _flag bool  Disable hash validation flag
    function _setDisableHashValidation(bool _flag) private {
        disableHashValidation = _flag;
        emit SetDisableHashValidationEvent(_flag);
    }

    /// Return chain type by id
    /// @param _chainId uint64  Chain id
    /// @return uint8  Chain type
    function _getChainType(uint64 _chainId) internal view returns(uint8) {
        return initializerLib.getChainType(_chainId);
    }

    /// Add trusted address
    /// @param _chainId uint64  Chain ID
    /// @param _trustedAddress address  Trusted address
    function addTrustedAddress(uint64 _chainId, uint _trustedAddress) public onlyOwner {
        trustedAddresses[_chainId].exists = true;
        trustedAddresses[_chainId].trustedAddress = _trustedAddress;
        trustedAddresses[_chainId].chainType = initializerLib.getChainType(_chainId);

        emit AddTrustedAddressEvent(_chainId, _trustedAddress);
    }

    /// Add trusted addresses
    /// @param _chainIds uint64[]  Chain IDs
    /// @param _trustedAddresses uint[]  Trusted addresses
    function addTrustedAddresses(uint64[] calldata _chainIds, uint[] calldata _trustedAddresses) external onlyOwner {
        for (uint i = 0; i < _chainIds.length; i++) {
            addTrustedAddress(_chainIds[i], _trustedAddresses[i]);
        }
    }

    /// Remove trusted address
    /// @param _chainId uint64  Chain ID
    function removeTrustedAddress(uint64 _chainId) external onlyOwner {
        require(trustedAddresses[_chainId].exists, "AsterizmClient: trusted address not found");
        uint removingAddress = trustedAddresses[_chainId].trustedAddress;
        delete trustedAddresses[_chainId];

        emit RemoveTrustedAddressEvent(_chainId, removingAddress);
    }

    /// Build transfer hash
    /// @param _srcChainId uint64  Chain ID
    /// @param _srcAddress uint  Address
    /// @param _dstChainId uint64  Chain ID
    /// @param _dstAddress uint  Address
    /// @param _txId uint  Transaction ID
    /// @param _payload bytes  Payload
    function _buildTransferHash(uint64 _srcChainId, uint _srcAddress, uint64 _dstChainId, uint _dstAddress, uint _txId, bytes memory _payload) internal view returns(bytes32) {
        bytes memory encodeData = abi.encodePacked(_srcChainId, _srcAddress, _dstChainId, _dstAddress, _txId, _buildPackedPayload(_payload));

        return _getChainType(_srcChainId) == _getChainType(_dstChainId) ? encodeData.buildSimpleHash() : encodeData.buildCrosschainHash();
    }

    /// Check is transfer hash valid
    /// @param _srcChainId uint64  Chain ID
    /// @param _srcAddress uint  Address
    /// @param _dstChainId uint64  Chain ID
    /// @param _dstAddress uint  Address
    /// @param _txId uint  Transaction ID
    /// @param _payload bytes  Packed payload
    /// @param _transferHash bytes32  Transfer hash
    function _validTransferHash(uint64 _srcChainId, uint _srcAddress, uint64 _dstChainId, uint _dstAddress, uint _txId, bytes memory _payload, bytes32 _transferHash) internal view returns(bool) {
        return _buildTransferHash(_srcChainId, _srcAddress, _dstChainId, _dstAddress, _txId, _payload) == _transferHash;
    }

    /// Return txId
    /// @return uint
    function _getTxId() internal view returns(uint) {
        return txId;
    }

    /// Return local chain id
    /// @return uint64
    function _getLocalChainId() internal view returns(uint64) {
        return localChainId;
    }

    /// Return initializer address
    /// @return address
    function getInitializerAddress() external view returns(address) {
        return address(initializerLib);
    }

    /// Return trusted src addresses
    /// @param _chainId uint64  Chain id
    /// @return AsterizmChain
    function getTrustedAddresses(uint64 _chainId) external view returns(AsterizmChain memory) {
        return trustedAddresses[_chainId];
    }

    /// Return use force order flag
    /// @return bool
    function getUseForceOrder() external view returns(bool) {
        return useForceOrder;
    }

    /// Return disable hash validation flag
    /// @return bool
    function getDisableHashValidation() external view returns(bool) {
        return disableHashValidation;
    }

    /** External logic */

    /** Sending logic */

    /// Initiate transfer event
    /// Generate event for client server
    /// @param _dstChainId uint64  Destination chain ID
    /// @param _payload bytes  Payload
    function _initAsterizmTransferEvent(uint64 _dstChainId, bytes memory _payload) internal {
        require(trustedAddresses[_dstChainId].exists, "AsterizmClient: trusted address not found");
        uint id = txId++;
        bytes32 transferHash = _buildTransferHash(_getLocalChainId(), address(this).toUint(), _dstChainId, trustedAddresses[_dstChainId].trustedAddress, id, _payload);
        outboundTransfers[transferHash].successReceive = true;
        emit InitiateTransferEvent(_dstChainId, trustedAddresses[_dstChainId].trustedAddress, id, transferHash, _payload);
    }

    /// External initiation transfer
    /// This function needs for external initiating non-encoded payload transfer
    /// @param _dstChainId uint64  Destination chain ID
    /// @param _transferHash bytes32  Transfer hash
    /// @param _txId uint  Transaction ID
    /// @param _payload bytes  Payload
    function initAsterizmTransfer(uint64 _dstChainId, uint _txId, bytes32 _transferHash, bytes calldata _payload) external payable onlyOwner nonReentrant {
        require(trustedAddresses[_dstChainId].exists, "AsterizmClient: trusted address not found");
        ClInitTransferRequestDto memory dto = _buildClInitTransferRequestDto(_dstChainId, trustedAddresses[_dstChainId].trustedAddress, _txId, _transferHash, msg.value, _payload);
        _initAsterizmTransferPrivate(dto);
    }

    /// Private initiation transfer
    /// This function needs for internal initiating non-encoded payload transfer
    /// @param _dto ClInitTransferRequestDto  Init transfer DTO
    function _initAsterizmTransferPrivate(ClInitTransferRequestDto memory _dto) private
    onlyExistsOutboundTransfer(_dto.transferHash)
    onlyNotExecutedOutboundTransfer(_dto.transferHash)
    {
        require(address(this).balance >= _dto.feeAmount, "AsterizmClient: contract balance is not enough");
        require(_dto.txId <= _getTxId(), "AsterizmClient: wrong txId param");
        initializerLib.initTransfer{value: _dto.feeAmount} (
            _buildIzIninTransferRequestDto(_dto.dstChainId, _dto.dstAddress, _dto.txId, _dto.transferHash, useForceOrder, _dto.payload)
        );
        outboundTransfers[_dto.transferHash].successExecute = true;
    }

    /// Resend failed by fee amount transfer
    /// @param _transferHash bytes32  Transfer hash
    function resendAsterizmTransfer(bytes32 _transferHash) external payable
    onlyOwner
    onlyExistsOutboundTransfer(_transferHash)
    onlyExecutedOutboundTransfer(_transferHash)
    {
        initializerLib.resendTransfer{value: msg.value}(_transferHash);
        emit ResendAsterizmTransferEvent(_transferHash, msg.value);
    }

    /** Receiving logic */

    /// Receive payload from initializer
    /// @param _dto ClAsterizmReceiveRequestDto  Method DTO
    function asterizmIzReceive(ClAsterizmReceiveRequestDto calldata _dto) external onlyInitializer {
        _asterizmReceiveExternal(_dto);
    }

    /// Receive external payload
    /// @param _dto ClAsterizmReceiveRequestDto  Method DTO
    function _asterizmReceiveExternal(ClAsterizmReceiveRequestDto calldata _dto) private
    onlyOwnerOrInitializer
    onlyTrustedAddress(_dto.srcChainId, _dto.srcAddress)
    onlyNonExecuted(_dto.transferHash)
    {
        inboundTransfers[_dto.transferHash].successReceive = true;
        emit PayloadReceivedEvent(_dto.srcChainId, _dto.srcAddress, _dto.nonce, _dto.txId, _dto.transferHash, _dto.payload);
    }

    /// Receive payload from client server
    /// @param _srcChainId uint64  Source chain ID
    /// @param _srcAddress uint  Source address
    /// @param _nonce uint  Nonce
    /// @param _txId uint  Transaction ID
    /// @param _transferHash bytes32  Transfer hash
    /// @param _payload bytes  Payload
    function asterizmClReceive(uint64 _srcChainId, uint _srcAddress, uint _nonce, uint _txId, bytes32 _transferHash, bytes calldata _payload) external onlyOwner nonReentrant {
        ClAsterizmReceiveRequestDto memory dto = _buildClAsterizmReceiveRequestDto(_srcChainId, _srcAddress, localChainId, address(this).toUint(), _nonce, _txId, _transferHash, _payload);
        _asterizmReceiveInternal(dto);
    }

    /// Receive non-encoded payload for internal usage
    /// @param _dto ClAsterizmReceiveRequestDto  Method DTO
    function _asterizmReceiveInternal(ClAsterizmReceiveRequestDto memory _dto) private
    onlyOwnerOrInitializer
    onlyReceivedTransfer(_dto.transferHash)
    onlyTrustedAddress(_dto.srcChainId, _dto.srcAddress)
    onlyTrustedTransfer(_dto.transferHash)
    onlyNonExecuted(_dto.transferHash)
    onlyValidTransferHash(_dto)
    {
        _asterizmReceive(_dto);
        inboundTransfers[_dto.transferHash].successExecute = true;
    }

    /// Receive payload
    /// You must realize this function if you want to transfer payload
    /// If disableHashValidation = true you must validate transferHash with _validTransferHash() method for more security!
    /// @param _dto ClAsterizmReceiveRequestDto  Method DTO
    function _asterizmReceive(ClAsterizmReceiveRequestDto memory _dto) internal virtual {}

    /// Build packed payload (abi.encodePacked() result)
    /// @param _payload bytes  Default payload (abi.encode() result)
    /// @return bytes  Packed payload (abi.encodePacked() result)
    function _buildPackedPayload(bytes memory _payload) internal view virtual returns(bytes memory) {}
}
