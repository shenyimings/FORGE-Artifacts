// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./basic-tokens/interfaces/IGateway.sol";

contract WhitelistMinter {
    using SafeERC20 for IERC20;

    address public gateway;
    // tokenAddress => tokenId => limitForTokenID => mintedAmount
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) mintedTokenId;
    // recipientAddress => limitForBuyerID => mintedAmount
    mapping(address => mapping(uint256 => uint256)) mintedBuyerId;

    event Mint(
        address indexed recipient,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        uint256 amount,
        address paymentTokenAddress,
        uint256 paymentTokenAmount,
        address payee
    );

    constructor(address _gateway) {
        gateway = _gateway;
    }

    /**
     * Allow users to mint NFTs if they hold the signature of
     * the corresponing NFT Manger.
     *
     * @param _tokenType true for ERC721
     * @param _tokenAddress the token to be minted, must be ERC721 / ERC1155
     * @param _tokenId the token to be minted, `0` means auto-increment id
     * @param _amount amount of tokens to be minted. For ERC721, amount == 1
     * @param _limits uint256[4]
     *        [0] _limitForBuyerID
     *        [1] _limitForBuyerAmount
     *        [2] _limitForTokenID
     *        [3] _limitForTokenAmount
     * @param _paymentTokenAddress the token used for the payment
     * @param _paymentTokenAmount the price of the NFT
     * @param _deadline signature expiration time
     * @param _sig the signature provided by the backend, on behalf of nft manager
     */
    function mintWithSig(
        bool _tokenType,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256[4] calldata _limits,
        address _paymentTokenAddress, // The payment ERC20 token
        uint256 _paymentTokenAmount, // The payment ERC20 token ammount
        uint256 _deadline,
        bytes calldata _sig // Signature provided by the backend
    ) external payable {
        // Check if before deadline
        require(block.timestamp <= _deadline, "WhitelistMinter: too late");

        require(
            _tokenId != 0 || _tokenType == true,
            "WhitelistMinter: cannot mint `0` for non-ERC721 tokens"
        );

        // Check if limitations hold
        require(
            mintedBuyerId[msg.sender][_limits[0]] + _amount <= _limits[1],
            "WhitelistMinter: buyer limit exceeded"
        );
        require(
            mintedTokenId[_tokenAddress][_tokenId][_limits[2]] + _amount <=
                _limits[3],
            "WhitelistMinter: token limit exceeded"
        );

        // Check signature validity
        bytes32 inputHash = _getInputHash(
            _tokenType,
            _tokenAddress,
            _tokenId,
            _amount,
            _limits,
            _paymentTokenAddress,
            _paymentTokenAmount,
            _deadline
        );
        address signer = IGateway(gateway).nftManager(_tokenAddress);
        _checkSigValidity(inputHash, _sig, signer);

        // TODO TBD
        address payeeAddress = signer;

        // Transfer payment tokens
        if (_paymentTokenAddress == address(0)) {
            require(
                msg.value == _paymentTokenAmount,
                "WhitelistMinter: Wrong native token amount"
            );
            (bool sent, ) = payeeAddress.call{value: _paymentTokenAmount}("");
            require(sent, "WhitelistMinter: Failed to send Ether to signer");
        } else if (_paymentTokenAmount != 0) {
            IERC20(_paymentTokenAddress).safeTransferFrom(
                msg.sender,
                payeeAddress,
                _paymentTokenAmount
            );
        }

        // Mint NFTs to the payer
        if (_tokenType) {
            IGateway(gateway).ERC721_mint(_tokenAddress, msg.sender, _tokenId);
        } else {
            IGateway(gateway).ERC1155_mint(
                _tokenAddress,
                msg.sender,
                _tokenId,
                _amount,
                "0x"
            );
        }

        mintedBuyerId[msg.sender][_limits[0]] += _amount;
        mintedTokenId[_tokenAddress][_tokenId][_limits[2]] += _amount;

        // Emit the Mint event
        emit Mint(
            msg.sender,
            _tokenAddress,
            _tokenId,
            _amount,
            _paymentTokenAddress,
            _paymentTokenAmount,
            payeeAddress
        );
    }

    function _getInputHash(
        bool _tokenType,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256[4] memory _limits,
        address _paymentTokenAddress,
        uint256 _paymentTokenAmount,
        uint256 _deadline
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    _tokenType,
                    _tokenAddress,
                    _tokenId,
                    _amount,
                    _limits,
                    _paymentTokenAddress,
                    _paymentTokenAmount,
                    _deadline,
                    block.chainid
                )
            );
    }

    function _checkSigValidity(
        bytes32 hash,
        bytes memory sig,
        address signer
    ) internal pure {
        require(
            signer == ECDSA.recover(_getEthSignedMessageHash(hash), sig),
            "WhitelistMinter: invalid signature"
        );
    }

    function _getEthSignedMessageHash(bytes32 criteriaMessageHash)
        internal
        pure
        returns (bytes32)
    {
        return ECDSA.toEthSignedMessageHash(criteriaMessageHash);
    }
    
    function getMintedAmtByTokenId(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _limitForTokenID
    ) external view returns (uint256) {
        return mintedTokenId[_tokenAddress][_tokenId][_limitForTokenID];
    }

    function getMintedAmtByBuyerId(
        address _recipientAddress,
        uint256 _limitForBuyerID
    ) external view returns (uint256) {
        return mintedBuyerId[_recipientAddress][_limitForBuyerID];
    }
}
