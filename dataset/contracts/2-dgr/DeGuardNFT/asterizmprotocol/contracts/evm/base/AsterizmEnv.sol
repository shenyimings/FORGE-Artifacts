// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../interfaces/IAsterizmEnv.sol";

abstract contract AsterizmEnv is IAsterizmEnv {

    /// Build initializer receive payload request DTO
    /// @param _srcChainId uint64  Source chain ID
    /// @param _srcAddress uint  Source address
    /// @param _dstChainId uint64  Destination chain ID
    /// @param _dstAddress uint  Destination address
    /// @return BaseTransferDirectionDto
    function _buildBaseTransferDirectionDto(
        uint64 _srcChainId, uint _srcAddress,
        uint64 _dstChainId, uint _dstAddress
    ) internal pure returns(BaseTransferDirectionDto memory) {
        BaseTransferDirectionDto memory dto;
        dto.srcChainId = _srcChainId;
        dto.srcAddress = _srcAddress;
        dto.dstChainId = _dstChainId;
        dto.dstAddress = _dstAddress;

        return dto;
    }

    /// Build client initiation transfer request DTO
    /// @param _dstChainId uint64  Destination chain ID
    /// @param _dstAddress uint  Destination address
    /// @param _transferHash bytes32  Transfer hash
    /// @param _feeAmount uint  Fee amount
    /// @param _txId uint  Transaction ID
    /// @param _payload bytes  Payload
    /// @return ClInitTransferRequestDto
    function _buildClInitTransferRequestDto(uint64 _dstChainId, uint _dstAddress, uint _txId, bytes32 _transferHash, uint _feeAmount, bytes memory _payload) internal pure returns(ClInitTransferRequestDto memory) {
        ClInitTransferRequestDto memory dto;
        dto.dstChainId = _dstChainId;
        dto.dstAddress = _dstAddress;
        dto.transferHash = _transferHash;
        dto.feeAmount = _feeAmount;
        dto.txId = _txId;
        dto.payload = _payload;

        return dto;
    }

    /// Build iuntrnal client initiation transfer request DTO
    /// @param _dstChainId uint64  Destination chain ID
    /// @param _dstAddress uint  Destination address
    /// @param _feeAmount uint  Fee amount
    /// @param _payload bytes  Payload
    /// @return InternalClInitTransferRequestDto
    function _buildInternalClInitTransferRequestDto(uint64 _dstChainId, uint _dstAddress, uint _feeAmount, bytes memory _payload) internal pure returns(InternalClInitTransferRequestDto memory) {
        InternalClInitTransferRequestDto memory dto;
        dto.dstChainId = _dstChainId;
        dto.dstAddress = _dstAddress;
        dto.feeAmount = _feeAmount;
        dto.payload = _payload;

        return dto;
    }

    /// Build translator send message request DTO
    /// @param _srcAddress uint  Source address
    /// @param _dstChainId uint64  Destination chain ID
    /// @param _dstAddress uint  Destination address
    /// @param _nonce uint  Nonce
    /// @param _forceOrder bool  Force order flag
    /// @param _txId uint  Transaction ID
    /// @param _transferHash bytes32  Transfer hash
    /// @param _payload bytes  Payload
    /// @return TrSendMessageRequestDto
    function _buildTrSendMessageRequestDto(
        uint _srcAddress, uint64 _dstChainId, uint _dstAddress, uint _nonce,
        bool _forceOrder, uint _txId, bytes32 _transferHash, bytes calldata _payload
    ) internal pure returns(TrSendMessageRequestDto memory) {
        TrSendMessageRequestDto memory dto;
        dto.srcAddress = _srcAddress;
        dto.dstChainId = _dstChainId;
        dto.dstAddress = _dstAddress;
        dto.nonce = _nonce;
        dto.forceOrder = _forceOrder;
        dto.txId = _txId;
        dto.transferHash = _transferHash;
        dto.payload = _payload;

        return dto;
    }

    /// Build translator transfer message request DTO
    /// @param _gasLimit uint  Gas limit
    /// @param _payload bytes  Payload
    /// @return TrTransferMessageRequestDto
    function _buildTrTarnsferMessageRequestDto(uint _gasLimit, bytes memory _payload) internal pure returns(TrTransferMessageRequestDto memory) {
        TrTransferMessageRequestDto memory dto;
        dto.gasLimit = _gasLimit;
        dto.payload = _payload;

        return dto;
    }

    /// Build initializer init transfer request DTO
    /// @param _dstChainId uint64  Destination chain ID
    /// @param _dstAddress uint  Destination address
    /// @param _txId uint  Transaction ID
    /// @param _transferHash bytes32  Transfer hash
    /// @param _useForceOrder bool  Use force order flag
    /// @param _payload bytes  Payload
    /// @return IzIninTransferRequestDto
    function _buildIzIninTransferRequestDto(uint64 _dstChainId, uint _dstAddress, uint _txId, bytes32 _transferHash, bool _useForceOrder, bytes memory _payload) internal pure returns(IzIninTransferRequestDto memory) {
        IzIninTransferRequestDto memory dto;
        dto.dstChainId = _dstChainId;
        dto.dstAddress = _dstAddress;
        dto.txId = _txId;
        dto.transferHash = _transferHash;
        dto.useForceOrder = _useForceOrder;
        dto.payload = _payload;

        return dto;
    }

    /// Build client asterizm receive request DTO
    /// @param _srcChainId uint64  Source chain ID
    /// @param _srcAddress uint  Source address
    /// @param _dstChainId uint64  Destination chain ID
    /// @param _dstAddress uint  Destination address
    /// @param _nonce uint  Nonce
    /// @param _txId uint  Transaction ID
    /// @param _transferHash bytes32  Transfer hash
    /// @param _payload bytes  Payload
    /// @return ClAsterizmReceiveRequestDto
    function _buildClAsterizmReceiveRequestDto(
        uint64 _srcChainId, uint _srcAddress, uint64 _dstChainId, uint _dstAddress,
        uint _nonce, uint _txId, bytes32 _transferHash, bytes memory _payload
    ) internal pure returns(ClAsterizmReceiveRequestDto memory) {
        ClAsterizmReceiveRequestDto memory dto;
        dto.srcChainId = _srcChainId;
        dto.srcAddress = _srcAddress;
        dto.dstChainId = _dstChainId;
        dto.dstAddress = _dstAddress;
        dto.nonce = _nonce;
        dto.txId = _txId;
        dto.transferHash = _transferHash;
        dto.payload = _payload;

        return dto;
    }

    /// Build initializer receive payload request DTO
    /// @param _baseTransferDirectioDto BaseTransferDirectionDto  Base transfer direction DTO
    /// @param _nonce uint  Nonce
    /// @param _gasLimit uint  Gas limit
    /// @param _forceOrder bool  Force order flag
    /// @param _txId uint  Transaction ID
    /// @param _transferHash bytes32  Transfer hash
    /// @param _payload bytes  Payload
    /// @return IzReceivePayloadRequestDto
    function _buildIzReceivePayloadRequestDto(
        BaseTransferDirectionDto memory _baseTransferDirectioDto,
        uint _nonce, uint _gasLimit, bool _forceOrder, uint _txId, bytes32 _transferHash, bytes memory _payload
    ) internal pure returns(IzReceivePayloadRequestDto memory) {
        IzReceivePayloadRequestDto memory dto;
        dto.srcChainId = _baseTransferDirectioDto.srcChainId;
        dto.srcAddress = _baseTransferDirectioDto.srcAddress;
        dto.dstChainId = _baseTransferDirectioDto.dstChainId;
        dto.dstAddress = _baseTransferDirectioDto.dstAddress;
        dto.nonce = _nonce;
        dto.gasLimit = _gasLimit;
        dto.forceOrder = _forceOrder;
        dto.txId = _txId;
        dto.transferHash = _transferHash;
        dto.payload = _payload;

        return dto;
    }

    /// Build initializer retry payload request DTO
    /// @param _srcChainId uint64  Source chain ID
    /// @param _srcAddress uint  Source address
    /// @param _dstChainId uint64  Destination chain ID
    /// @param _dstAddress uint  Destination address
    /// @param _nonce uint  Nonce
    /// @param _gasLimit uint  Gas limit
    /// @param _forceOrder bool  Force order flag
    /// @param _transferHash bytes32  Transfer hash
    /// @param _payload bytes  Payload
    /// @return IzRetryPayloadRequestDto
    function _buildIzRetryPayloadRequestDto(
        uint64 _srcChainId, uint _srcAddress, uint64 _dstChainId, uint _dstAddress,
        uint _nonce, uint _gasLimit, bool _forceOrder, bytes32 _transferHash, bytes calldata _payload
    ) internal pure returns(IzRetryPayloadRequestDto memory) {
        IzRetryPayloadRequestDto memory dto;
        dto.srcChainId = _srcChainId;
        dto.srcAddress = _srcAddress;
        dto.dstChainId = _dstChainId;
        dto.dstAddress = _dstAddress;
        dto.nonce = _nonce;
        dto.gasLimit = _gasLimit;
        dto.forceOrder = _forceOrder;
        dto.transferHash = _transferHash;
        dto.payload = _payload;

        return dto;
    }
}
