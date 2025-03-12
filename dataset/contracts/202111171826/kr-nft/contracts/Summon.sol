// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./Interfaces/IHero.sol";

contract Summon is Ownable, Pausable {

    using Address for address;
    using SafeMath for uint256;
    using ECDSA for bytes32;

    // Price (in wei) for the summon
    IERC20 public acceptedToken;
    uint256 public fee;
    address public signerPublicKey;
    address public heroSmartContractAddress;

    mapping(string => bool) executed;

    constructor(
        uint256 _fee,
        address _acceptedTokenAddress,
        address _heroSmartContractAddress
    ) {
        fee = _fee;

        require(
            _heroSmartContractAddress.isContract(),
            "The hero contract address must be a deployed contract"
        );
        heroSmartContractAddress = _heroSmartContractAddress;

        setAcceptedToken(_acceptedTokenAddress);
    }

    function setSignerPublicKey(address newSignerPublicKey) public onlyOwner {
        signerPublicKey = newSignerPublicKey;
    }

    function setAcceptedToken(address newAcceptedTokenAddress)
        public
        onlyOwner
    {
        require(
            newAcceptedTokenAddress.isContract(),
            "The accepted token address must be a deployed contract"
        );
        acceptedToken = IERC20(newAcceptedTokenAddress);
    }

    function setHeroSmartContractAddress(address newHeroSmartContractAddress)
        public
        onlyOwner
    {
        heroSmartContractAddress = newHeroSmartContractAddress;
    }

    function setFee(uint256 newFee) public onlyOwner {
        fee = newFee;
    }

    function summon(string memory _nonce,bytes memory signature)
        external
        whenNotPaused
        returns (uint256)
    {
        require(!executed[_nonce], "Summon: nonce already used");

        address _sender = _msgSender();

        address signer = keccak256(abi.encode(_nonce, _sender))
            .toEthSignedMessageHash()
            .recover(signature);

        require(signer == signerPublicKey, "Summon: Invalid signature");

        // Transfer fee to owner
        if (acceptedToken.transferFrom(_sender, owner(), fee)) {
            try
                IHero(heroSmartContractAddress).mintWithSummon(_sender)
            returns (uint256 heroId) {
                executed[_nonce] = true;
                return heroId;
            } catch {
                revert("Summon: failed to mint a new hero");
            }
        } else {
            revert("Summon: failed to transfer fee to owner");
        }
    }
}
