// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract AirDrop is Initializable, Ownable {
    IERC20 public token;

    bytes32 public merkleRoot;

    uint256 public dateOfExpiry;

    bool public isInitialized;

    mapping(address => bool) public claimedAirDrop;

    event Initialized(address token, uint256 totalAmount, bytes32 merkleRoot, uint256 dateOfExpiry);

    event Claimed(address indexed claimer, uint256 amount);

    constructor(address _owner) {
        if (_owner != msg.sender) {
            transferOwnership(_owner);
        }
    }

    function initialize(
        IERC20 _token,
        bytes32 _merkleRoot,
        uint256 _expiresIn
    ) external initializer onlyOwner {
        address self = address(this);

        uint256 totalAmount = _token.balanceOf(self);

        require(totalAmount > 0, "An insufficient amount");
        require(_expiresIn > 0, "expiry must be greater than zero");

        token = _token;
        merkleRoot = _merkleRoot;
        uint256 _dateOfExpiry = block.timestamp + _expiresIn;
        dateOfExpiry = _dateOfExpiry;
        isInitialized = true;

        emit Initialized(address(_token), totalAmount, _merkleRoot, _dateOfExpiry);
    }

    function claimAirDrop(uint256 _amount, bytes32[] calldata _merkleProof) external {
        require(canClaimAirDrop(msg.sender, _amount, _merkleProof), "Access denied");

        claimedAirDrop[msg.sender] = true;

        token.transfer(msg.sender, _amount);

        emit Claimed(msg.sender, _amount);
    }

    function canClaimAirDrop(
        address _claimer,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) public view returns (bool) {
        require(isInitialized, "Airdrop has not been initialized yet");
        require(!isExpired(), "Cannot be claimed after the end of the distribution");
        return
            _amount > 0 &&
            balance() >= _amount &&
            !claimedAirDrop[_claimer] &&
            MerkleProof.verify(_merkleProof, merkleRoot, keccak256(abi.encodePacked(_claimer, _amount)));
    }

    function withdrawAfterExipired(address _recipient) external onlyOwner {
        require(isExpired(), "Cannot be withdrawn until the end of the distribution");
        uint256 _balance = balance();
        require(_balance > 0, "Insufficient funds to withdraw");
        token.transfer(_recipient, _balance);
    }

    function isExpired() public view returns (bool) {
        return block.timestamp > dateOfExpiry;
    }

    function balance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
