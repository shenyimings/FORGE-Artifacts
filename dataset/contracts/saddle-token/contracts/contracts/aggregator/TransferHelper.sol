// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "./SpecialTransferHelper.sol";
import "./AggregatorStructs.sol";

/// @title Helper contract used to transfer tokens
contract TransferHelper is Initializable, ContextUpgradeable, SpecialTransferHelper {
    address public CRYPTO_PUNK;
    address public MOONCAT;

    function __TransferHelper_init(address _cryptoPunk, address _mooncat) internal initializer {
        __Context_init_unchained();
        __SpecialTransfer_init();

        CRYPTO_PUNK = _cryptoPunk;
        MOONCAT = _mooncat;
    }

    function _checkCallResult(bool _success) internal pure {
        if (!_success) {
            assembly {
                // revert reason from call
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return 0x150b7a02;
    }

    // Used by ERC721BasicToken.sol
    function onERC721Received(
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return 0xf0b9e5ba;
    }

    function supportsInterface(bytes4 interfaceId) external view virtual returns (bool) {
        return interfaceId == this.supportsInterface.selector;
    }

    receive() external payable {}

    /**
     * @notice _transferEth is a helper function that transfers ETH
     * @param _to is the recipient
     * @param _amount is the amount of ETH in WEI
     */
    function _transferEth(address _to, uint256 _amount) internal {
        bool callStatus;
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            callStatus := call(gas(), _to, _amount, 0, 0, 0, 0)
        }
        require(callStatus, "_transferEth: Eth transfer failed");
    }

    /**
     * @notice _transferFromHelper is a helper function that transfers erc20s, erc721s and 1155s
     * @param erc20Details is a struct containing fields for array of erc20s and amounts
     * @param erc721Details is an array of erc721s, including tokenId, recipient and token contract
     * @param erc1155Details is an array of erc1155s, including tokenIds, amounts and token contract.
       Recipient is address(this)
     */
    function _transferFromHelper(
        ERC20Details memory erc20Details,
        ERC721Details[] memory erc721Details,
        ERC1155Details[] memory erc1155Details
    ) internal {
        for (uint256 i = 0; i < erc20Details.tokenAddrs.length; i++) {
            // bytes4(keccak256('transferFrom(address,address,uint256)')) == 0x23b872dd
            erc20Details.tokenAddrs[i].call(
                abi.encodeWithSelector(0x23b872dd, msg.sender, address(this), erc20Details.amounts[i])
            );
        }

        // transfer ERC721 tokens from the sender to this contract
        for (uint256 i = 0; i < erc721Details.length; i++) {
            // accept CryptoPunks
            if (erc721Details[i].tokenAddr == CRYPTO_PUNK) { // 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB
                _acceptCryptoPunk(erc721Details[i]);
            }
            // accept Mooncat
            else if (erc721Details[i].tokenAddr == MOONCAT) { // 0x60cd862c9C687A9dE49aecdC3A99b74A4fc54aB6
                _acceptMoonCat(erc721Details[i]);
            }
            // default
            else {
                for (uint256 j = 0; j < erc721Details[i].ids.length; j++) {
                    IERC721Upgradeable(erc721Details[i].tokenAddr).transferFrom(
                        _msgSender(),
                        address(this),
                        erc721Details[i].ids[j]
                    );
                }
            }
        }

        // transfer ERC1155 tokens from the sender to this contract
        for (uint256 i = 0; i < erc1155Details.length; i++) {
            IERC1155Upgradeable(erc1155Details[i].tokenAddr).safeBatchTransferFrom(
                _msgSender(),
                address(this),
                erc1155Details[i].ids,
                erc1155Details[i].amounts,
                ""
            );
        }
    }

    /**
     * @notice _returnDust is a helper function that allows tokens to be returned at the end of a call
     * @param _tokens is an array of ERC20 token contract addresses
     */
    function _returnDust(
        address[] memory _tokens
    ) internal {
        assembly { // send back ETH
            if gt(selfbalance(), 0) {
                let callStatus := call(gas(), caller(), selfbalance(), 0, 0, 0, 0)
            }
        }

        for (uint256 i = 0; i < _tokens.length; i++) {
            if (IERC20Upgradeable(_tokens[i]).balanceOf(address(this)) > 0) {
                // bytes4(keccak256('transfer(address,uint256)')) == 0xa9059cbb
                _tokens[i].call(
                    abi.encodeWithSelector(
                        0xa9059cbb,
                        msg.sender,
                        IERC20Upgradeable(_tokens[i]).balanceOf(address(this))
                    )
                );
            }
        }
    }

    uint256[49] private __gap;
}