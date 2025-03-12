// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../libraries/ScaledMath.sol";
import "../interfaces/IConicDebtToken.sol";

contract ConicDebtToken is IConicDebtToken, ERC20, Ownable {
    using SafeERC20 for IERC20;
    using MerkleProof for MerkleProof.Proof;

    uint256 internal constant MAX_SUPPLY = 5000000e18; // UPDATE to exact amount that was exploited
    uint256 internal constant CLAIM_DURATION = 30 days * 6;
    address internal constant CRVUSD = address(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E);
    bytes32 public immutable merkleRootDebtToken;
    bytes32 public immutable merkleRootRefund;

    mapping(address => bool) public debtTokenClaimedBy;
    mapping(address => bool) public refundClaimedBy;

    uint256 public startAt;
    bool public claimIsActive;
    address public claimPool;

    constructor(
        bytes32 _merkleRootDebtToken,
        bytes32 _merkleRootRefund
    ) ERC20("Conic Debt Token", "cncDT") {
        merkleRootDebtToken = _merkleRootDebtToken;
        merkleRootRefund = _merkleRootRefund;
    }

    function depositRefund(uint256 amount) external onlyOwner {
        IERC20(CRVUSD).safeTransferFrom(msg.sender, address(this), amount);
    }

    function start() external onlyOwner {
        startAt = block.timestamp;
        emit ClaimingStarted();
    }

    function claimDebtToken(uint256 amount, MerkleProof.Proof calldata proof) external {
        require(startAt != 0, "Claiming is not active");
        _claimDebtToken(amount, proof);
    }

    function claimRefund(uint256 amount, MerkleProof.Proof calldata proof) external {
        require(startAt != 0, "Claiming is not active");
        _claimRefund(amount, proof);
    }

    function claimAll(
        uint256 amountDebtToken,
        MerkleProof.Proof calldata proofDebtTokenClaim,
        uint256 amountRefund,
        MerkleProof.Proof calldata proofRefund
    ) external {
        require(startAt != 0, "Claiming is not active");

        _claimDebtToken(amountDebtToken, proofDebtTokenClaim);
        _claimRefund(amountRefund, proofRefund);
    }

    function _claimRefund(uint256 amount, MerkleProof.Proof calldata proof) internal {
        _claim(amount, proof, merkleRootRefund, refundClaimedBy);
        IERC20(CRVUSD).safeTransfer(msg.sender, amount);
        emit RefundClaimed(msg.sender, amount);
    }

    function _claimDebtToken(uint256 amount, MerkleProof.Proof calldata proof) internal {
        _claim(amount, proof, merkleRootDebtToken, debtTokenClaimedBy);
        _mint(msg.sender, amount);
        emit DebtTokenClaimed(msg.sender, amount);
    }

    function _claim(
        uint256 amount,
        MerkleProof.Proof calldata proof,
        bytes32 merkleRoot,
        mapping(address => bool) storage claimedBy
    ) internal {
        bytes32 node = keccak256(abi.encodePacked(msg.sender, amount));
        require(proof.isValid(node, merkleRoot), "Invalid proof");
        require(startAt + CLAIM_DURATION >= block.timestamp, "Claiming has ended");
        require(!claimedBy[msg.sender], "Already claimed");
        claimedBy[msg.sender] = true;
    }

    function setClaimPool(address _claimPool) external onlyOwner {
        claimPool = _claimPool;
        emit ClaimPoolSet(_claimPool);
    }

    function burn(uint256 amount) external override {
        require(msg.sender == claimPool, "invalid burner");
        _burn(msg.sender, amount);
    }
}
