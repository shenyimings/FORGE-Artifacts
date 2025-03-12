// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "openzeppelin-contracts/token/ERC1155/ERC1155.sol";
import "openzeppelin-contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/utils/Strings.sol";
import {UD60x18, sqrt, exp, ud, mul, div, intoUint256} from "@prb/math/UD60x18.sol";
import "./utils/BlockscapeAccess.sol";
import "./utils/BlockscapeShared.sol";

/** 
    @title Rocketpool Staking Allocation Contract - Blockscape ETH Stake NFT
    @author Blockscape Finance AG <info@blockscape.network>
    @notice collects ETH, mints NFT in return for stake, which can be any amount of ETH. 
    The ETH is staked in the blockscape rocketpool infrastructure.
*/
contract BlockscapeETHStakeNFT is
    ERC1155Supply,
    ReentrancyGuard,
    BlockscapeAccess,
    BlockscapeShared
{
    /// @notice tracks the ETH pool supply
    uint256 private poolSupply;

    /// @notice constant used for blockexplorers to display the name of the token 
    /// (as to be lower case as per blockexplorer standards)
    string public constant name = "Blockscape ETH Stake NFTs";

    /// @notice constant used for blockexplorers to display the symbol of the token 
    /// (as to be lower case as per blockexplorer standards)
    string public constant symbol = "BSS";

    /** 
        @notice each pool related vault gets its separate tokenID which depicts 
        the nft for each staker
        @dev the IPNS makes sure the nfts stay reachable via this link while 
        new nfts get added to the underlying ipfs folder
     */
    constructor()
        ERC1155(
            "https://ipfs.blockscape.network/ipns/"
            "TBD/"
            "{id}.json"
        )
        BlockscapeAccess(
            msg.sender,
            blockscapeRocketPoolNode,
            0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 //! TODO: change to correct address before deployment!
        )
    {}

    /**
     * @dev needed as the OZ ERC1155 && AccessControl does both implement the supportsInterface function
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice used by stakers to deposit ETH into the contract
     * @dev the vault must be open and enough RPL must be staked in the rocketpool by the node
     * @dev the msg.value must be greater than 0
     * @dev the msg.value is added to the poolSupply
     * @dev if contract balance is greater than 8 ETH, the ETH is sent to the rocketpool node
     */
    function depositStakeNFT() external payable nonReentrant {
        if (!hasNodeEnoughRPLStake()) revert NotEnoughRPLStake();

        if (!vaultOpen) revert ErrorVaultState(vaultOpen);

        if (msg.value == 0) revert MsgValueZero();

        _setMetadataForStakeInternal(msg.value, tokenID);
        _mint(msg.sender, tokenID, 1, "");

        tokenID++;
        poolSupply += msg.value;

        if (address(this).balance >= 8 ether) {
            Address.sendValue(blockscapeRocketPoolNode, address(this).balance);
        }
    }

    /**
        @notice update the stake of the given tokenID, if the NFT owner decides to stake more ETH
        @dev emits the StakeUpdated event & increases the poolSupply based on the msg.value
        @param _tokenID Identifier of the vault
    */
    function updateStake(uint256 _tokenID) external payable {
        if (balanceOf(msg.sender, _tokenID) >= 1) {
            if (msg.value == 0) revert MsgValueZero();

            tokenIDtoMetadata[_tokenID].stakedETH += msg.value;

            poolSupply += msg.value;

            emit StakeUpdated(
                _tokenID,
                msg.sender,
                tokenIDtoMetadata[_tokenID].stakedETH
            );
        } else {
            revert YouDontOwnThisNft(_tokenID);
        }
    }

    /**
        @notice Withdraw is a two step process, first the staker has to call prepareWithdrawalProcess()
        @dev first step used by the staker when he or she wants to unstake
        @param _tokenID which ETH Stake NFT the staker wants to unstake
        the backend will listen on the event and will unstake the validator. 
        The ETH value with rewards is transparantly available 
        via beacon chain explorers and will be reduced by the withdraw fee, 
        which is fixed to 0.5% after one year.
     */
    function prepareWithdrawalProcess(uint256 _tokenID) external override {
        if (tokenIDToTimestamp[_tokenID] > 0) revert AlreadyPreparingForWithdrawal();

        tokenIDToExitReward[_tokenID] = calcRewards(_tokenID);

        if (balanceOf(msg.sender, _tokenID) >= 1) {
            tokenIDToTimestamp[_tokenID] = block.timestamp;
            emit UserRequestedWithdrawalStake(
                _tokenID,
                msg.sender,
                tokenIDtoMetadata[_tokenID].stakedETH,
                tokenIDToExitReward[_tokenID]
            );
        }
    }

    /**
     *  @notice used by the staker after prepareWithdrawalProcess() & the timelock has passed to withdraw the funds
     *  @dev the rewards are calculated by the backend controller and are then stored in the contract,
     *  this is needed to be able to calculate the rewards correctly including MEV rewards.
     *  There off-chain calculated rewards cannot be lower than the on-chain esimated rewards.
     */
    function withdrawFunds(uint256 _tokenID) external override nonReentrant {
        if (tokenIDToTimestamp[_tokenID] + timelockWithdraw >= block.timestamp)
            revert WithdrawalTimelockNotReached(
                tokenIDToTimestamp[_tokenID] + timelockWithdraw
            );

        safeTransferFrom(msg.sender, blockscapeRocketPoolNode, _tokenID, 1, "");

        Address.sendValue(
            payable(msg.sender),
            tokenIDtoMetadata[_tokenID].stakedETH +
                tokenIDToExitReward[_tokenID]
        );
        tokenIDToTimestamp[_tokenID] = 0;
    }

    /**
     * @notice returns the current ETH supply of the pool
     *
     */
    function getPoolSupply() public view returns (uint256) {
        return poolSupply;
    }

    /**
        @notice how much fees would the user have to pay if he or she would to unstake now
        within the first year of staking the fee is starting at 20% & decreasing linearly, afterwards 0.5%
        @param _tokenID which NFT the staker wants to unstake
        @return _amount how much the user would pay on fees in percent*1e18
     */
    function calcWithdrawFee(
        uint256 _tokenID,
        address _user
    ) public view override returns (uint256 _amount) {
        uint256 curWithdrawFee = initWithdrawFee;

        if (balanceOf(_user, _tokenID) >= 1) {
            uint256 secFee = (initWithdrawFee / 365 days); // 20%
            uint256 timePassed = block.timestamp -
                (tokenIDtoMetadata[_tokenID].stakedTimestamp);

            uint256 maxTime05EthReached = 30747600;
            if (timePassed >= maxTime05EthReached) {
                curWithdrawFee = 5 * 1e17; // fixed minimum fee 0,5 %
            } else {
                curWithdrawFee = (initWithdrawFee - (secFee * timePassed));
            }
        } else {
            curWithdrawFee = 0;
        }
        return curWithdrawFee;
    }

    /**
        @notice this function is a on-chain calculation of the rocketpool ETH rewards. 
        @notice It does take MEV (estimated) into account.
        @dev exp(((31556926 / 384) * 64) / 31622 / sqrt(balanceStaked)) - 1) * 100 - 0.5
        @dev 31556926 = seconds per year
        @dev 384 = seconds per epoch
        @dev 31556926 / 384 = epochs per year
        @dev 64 = BASE_REWARD_FACTOR
        @dev 31622 = sqrt(gwei per ETH)
        @dev 166.32368815e18 = ((31556926 / 384) * 64) / 31622
        @dev 0x00000000219ab540356cBB839Cbe05303d7705Fa = deposit contract address
        @return rewards annual procentage rate * 1e18
     */
    function calcApr() internal view returns (uint256) {
        UD60x18 balanceStaked = ud(
            address(0x00000000219ab540356cBB839Cbe05303d7705Fa).balance
        );
        uint256 baseAPR = (intoUint256(
            exp(div(ud(166.32368815e18), sqrt(balanceStaked)))
        ) - 1e18) *
            100 -
            5e17;
        uint256 ethreturn = (baseAPR * 16) / 100;
        uint256 mevreturn = 0.23e18;
        uint256 feereturn = 0.23e18;
        uint256 commission = (15 * ethreturn) / 100;
        uint256 totalETHReturn = ethreturn + mevreturn + feereturn + commission;
        return (totalETHReturn / 16) * 100;
    }

    /**
     * @notice calculates the rewards for the staker based on the current APR and the time staked
     * @param _tokenID which the rewards are calculated for
     * @return ETH rewards in wei minus the withdraw fee
     */
    function calcRewards(uint256 _tokenID) internal view returns (uint256) {
        uint256 secRewards = calcApr() / 365 days;
        uint256 secStaked = block.timestamp -
            tokenIDtoMetadata[_tokenID].stakedTimestamp;
        uint256 rewards = secRewards * secStaked;
        uint256 wFee = ((rewards * calcWithdrawFee(_tokenID, msg.sender)) /
            1e19);
        return (rewards - wFee);
    }

    /// @notice how many NFTs are there totally
    /// @return total amount of NFTs minted
    function totalSupply() external view returns (uint256) {
        uint256 amount = 0;
        for (uint256 i = 1; i <= getTokenID(); i++) {
            amount += totalSupply(i);
        }
        return amount;
    }

    /** 
        @notice stake nft metdata location
        @dev this path will never change as the contract defines a collection
        @return the fixed collection metadata path 
     */
    function contractURI() external pure returns (string memory) {
        return "https://ipfs.blockscape.network/ipfs/TBD";
    }

    /**
        @notice gets the url to the metadata of a given NFT tokenID
        @param _tokenID the pool
        @return the NFT metadata url
     */
    function uri(
        uint256 _tokenID
    ) public pure override returns (string memory) {
        return
            string.concat(
                "https://ipfs.blockscape.network/ipns/TBD/",
                Strings.toString(_tokenID),
                ".json"
            );
    }
}
