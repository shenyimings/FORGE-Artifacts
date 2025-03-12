// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./BaseTreasury.sol";
import "./interfaces/IMainTreasury.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/MerkleProof.sol";
import "./libraries/MiMC.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract MainTreasury is IMainTreasury, BaseTreasury, Initializable {
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public override verifier;

    uint64 public override zkpId;

    mapping(address => uint256) public override getBalanceRoot;
    mapping(address => uint256) public override getWithdrawRoot;
    mapping(address => uint256) public override getTotalBalance;
    mapping(address => uint256) public override getTotalWithdraw;
    mapping(address => uint256) public override getWithdrawn;

    mapping(address => bool) public override getWithdrawFinished;
    
    uint256 public override lastUpdateTime;
    uint256 public override forceTimeWindow;

    bool public override forceWithdrawOpened;

    struct WithdrawnInfo {
        mapping(uint256 => uint256) generalWithdrawnBitMap;
        mapping(uint256 => uint256) forceWithdrawnBitMap;
        uint256[] allGeneralWithdrawnIndex;
        uint256[] allForceWithdrawnIndex;
    }
    mapping(address => WithdrawnInfo) private getWithdrawnInfo;

    modifier onlyVerifierSet {
        require(verifier != address(0), "verifier not set");
        _;
    }

    function initialize(uint256 forceTimeWindow_) external initializer {
        owner = msg.sender;
        forceTimeWindow = forceTimeWindow_;
    }

    function setVerifier(address verifier_) external override onlyOwner {
        require(verifier == address(0), "verifier already set");
        verifier = verifier_;
        emit VerifierSet(verifier_);
    }

    function updateZKP(
        uint64 newZkpId,
        address[] calldata tokens,
        uint256[] calldata newBalanceRoots,
        uint256[] calldata newWithdrawRoots,
        uint256[] calldata newTotalBalances,
        uint256[] calldata newTotalWithdraws
    ) external override onlyVerifierSet {
        require(msg.sender == verifier, "forbidden");
        require(!forceWithdrawOpened, "force withdraw opened");
        require(
            tokens.length == newBalanceRoots.length &&
            newBalanceRoots.length == newWithdrawRoots.length &&
            newWithdrawRoots.length == newTotalBalances.length &&
            newTotalBalances.length == newTotalWithdraws.length,
            "length not the same"
        );

        uint256 balanceOfThis;
        address token;
        for (uint256 i = 0; i < tokens.length; i++) {
            token = tokens[i];
            require(getWithdrawFinished[token], "last withdraw not finish yet");
            getWithdrawFinished[token] = false;

            if (token == ETH) {
                balanceOfThis = address(this).balance;
            } else {
                balanceOfThis = IERC20(token).balanceOf(address(this));
            }
            require(balanceOfThis >= newTotalBalances[i] + newTotalWithdraws[i], "not enough balance");
            
            getBalanceRoot[token] = newBalanceRoots[i];
            getWithdrawRoot[token] = newWithdrawRoots[i];
            getTotalBalance[token] = newTotalBalances[i];
            getTotalWithdraw[token] = newTotalWithdraws[i];

            WithdrawnInfo storage withdrawnInfo = getWithdrawnInfo[token];
            // clear claimed records
            for (uint256 j = 0; j < withdrawnInfo.allGeneralWithdrawnIndex.length; j++) {
                delete withdrawnInfo.generalWithdrawnBitMap[withdrawnInfo.allGeneralWithdrawnIndex[j]];
            }
            delete withdrawnInfo.allGeneralWithdrawnIndex;
        }

        require(newZkpId > zkpId, "old zkp");
        zkpId = newZkpId;
        lastUpdateTime = block.timestamp;

        emit ZKPUpdated(newZkpId, tokens, newBalanceRoots, newWithdrawRoots, newTotalBalances, newTotalWithdraws);
    }

    function generalWithdraw(
        uint256[] calldata proof,
        uint256 index,
        uint256 withdrawId,
        uint256 accountId,
        address account,
        address to,
        address token,
        uint8 withdrawType,
        uint256 amount
    ) external override onlyVerifierSet {
        require(!isWithdrawn(token, index, true), "Drop already withdrawn");
        uint64 zkpId_ = zkpId;
        // Verify the merkle proof.
        uint256[] memory msgs = new uint256[](9);
        msgs[0] = zkpId_;
        msgs[1] = index;
        msgs[2] = withdrawId;
        msgs[3] = accountId;
        msgs[4] = uint256(uint160(account));
        msgs[5] = uint256(uint160(to));
        msgs[6] = uint256(uint160(token));
        msgs[7] = withdrawType;
        msgs[8] = amount;
        uint256 node = MiMC.Hash(msgs);
        require(MerkleProof.verify(proof, getWithdrawRoot[token], node), "Invalid proof");
        // Mark it withdrawn and send the token.
        _setWithdrawn(token, index, true);
        if (token == ETH) {
            TransferHelper.safeTransferETH(to, amount);
        } else {
            TransferHelper.safeTransfer(token, to, amount);
        }

        getWithdrawn[token] += amount;
        require(getWithdrawn[token] <= getTotalWithdraw[token], "over totalWithdraw");
        if (getWithdrawn[token] == getTotalWithdraw[token]) getWithdrawFinished[token] = true;

        emit GeneralWithdrawn(token, account, to, zkpId_, index, amount);
    }

    function forceWithdraw(
        uint256[] calldata proof,
        uint256 index,
        uint256 accountId,
        uint256 equity,
        address token
    ) external override onlyVerifierSet {
        require(block.timestamp > lastUpdateTime + forceTimeWindow, "not over forceTimeWindow");
        require(!isWithdrawn(token, index, false), "Drop already withdrawn");
        uint64 zkpId_ = zkpId;
        // Verify the merkle proof.
        uint256[] memory msgs = new uint256[](5);
        msgs[0] = index;
        msgs[1] = accountId;
        msgs[2] = uint256(uint160(msg.sender));
        msgs[3] = uint256(uint160(token));
        msgs[4] = equity;
        uint256 node = MiMC.Hash(msgs);
        require(MerkleProof.verify(proof, getBalanceRoot[token], node), "Invalid proof");
        // Mark it withdrawn and send the token.
        _setWithdrawn(token, index, false);
        if (token == ETH) {
            TransferHelper.safeTransferETH(msg.sender, equity);
        } else {
            TransferHelper.safeTransfer(token, msg.sender, equity);
        }

        if (!forceWithdrawOpened) forceWithdrawOpened = true;
        emit ForceWithdrawn(token, msg.sender, zkpId_, index, equity); 
    }

    function isWithdrawn(address token, uint256 index, bool isGeneral) public view returns (bool) {
        uint256 wordIndex = index / 256;
        uint256 bitIndex = index % 256;
        uint256 word;
        if (isGeneral) {
            word = getWithdrawnInfo[token].generalWithdrawnBitMap[wordIndex];
        } else {
            word = getWithdrawnInfo[token].forceWithdrawnBitMap[wordIndex];
        }
        uint256 mask = (1 << bitIndex);
        return word & mask == mask;
    }

    function _setWithdrawn(address token, uint256 index, bool isGeneral) internal {
        uint256 wordIndex = index / 256;
        uint256 bitIndex = index % 256;
        WithdrawnInfo storage withdrawnInfo = getWithdrawnInfo[token];
        if (isGeneral) {
            withdrawnInfo.generalWithdrawnBitMap[wordIndex] = withdrawnInfo.generalWithdrawnBitMap[wordIndex] | (1 << bitIndex);
            withdrawnInfo.allGeneralWithdrawnIndex.push(wordIndex);
        } else {
            withdrawnInfo.forceWithdrawnBitMap[wordIndex] = withdrawnInfo.forceWithdrawnBitMap[wordIndex] | (1 << bitIndex);
            withdrawnInfo.allForceWithdrawnIndex.push(wordIndex);
        }
    }
}