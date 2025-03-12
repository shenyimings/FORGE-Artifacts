//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./INFTPackage.sol";
import "./INFTPackageTrade.sol";

library SafeNFTPackage {
    using Address for address;

    function safeMintTo(
        INFTPackage token,
        address to,
        string memory pkg,
        string memory uri
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.mintTo.selector, to, pkg, uri));
    }

    function _callOptionalReturn(INFTPackage token, bytes memory data) private {
        address(token).functionCall(data);
    }
}

contract NFTPackageTrade is Ownable, Initializable, INFTPackageTrade {
    using ECDSA for bytes32;
    using ERC165Checker for address;
    using SafeERC20 for IERC20;
    using SafeNFTPackage for INFTPackage;

    address private _feeReceiver;
    mapping(address => bool) private verifiers;

    function initialize(address owner_) public initializer {
        transferOwnership(owner_);
        verifiers[owner_] = true;
        _feeReceiver = owner_;
    }

    function setVerifier(address verifier_) external override onlyOwner {
        verifiers[verifier_] = true;
    }

    function revokeVerifier(address verifier_) external override onlyOwner {
        verifiers[verifier_] = false;
    }

    function setFeeReceiver(address feeReceiver_) external override onlyOwner {
        _feeReceiver = feeReceiver_;
    }

    function hash(Order memory order) public view override returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                msg.sender,
                INFTUpgradeable(order.project).balanceOf(order.to),
                order.token,
                order.amount,
                order.fee,
                order.project,
                order.to,
                order.uri,
                order.package
            )
        );
    }

    function recoverVerifier(Order memory order, bytes memory sig) public view override returns (address) {
        return hash(order).toEthSignedMessageHash().recover(sig);
    }

    function _transferToken(address token, address from, address to, uint256 amount) internal {
        require(0 < amount);
        
        IERC20(token).safeTransferFrom(from, to, amount);
    }

    function mint(Order memory order, bytes memory sig) public payable override {
        address _verifier = recoverVerifier(order, sig);
        require(verifiers[_verifier], "403");
        
        address payable creator = payable(INFTUpgradeable(order.project).creator());
        uint256 transferAmount = order.amount - order.fee;
        if (address(0) == order.token) {
            require(order.amount <= msg.value);
            Address.sendValue(creator, transferAmount);
            if (0 < order.fee) {
                Address.sendValue(creator, order.fee);
            }
        }   else {
            _transferToken(order.token, msg.sender, creator, transferAmount);
            if (0 < msg.value) {
                Address.sendValue(creator, msg.value);
            }
        }
        
        INFTPackage(order.project).safeMintTo(order.to, order.package, order.uri);
    }
    uint256[50] private __gap;
}
