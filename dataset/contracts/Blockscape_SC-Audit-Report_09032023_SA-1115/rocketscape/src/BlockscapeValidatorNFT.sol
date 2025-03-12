// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "openzeppelin-contracts/token/ERC1155/ERC1155.sol";
import "openzeppelin-contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/utils/Strings.sol";

import "./utils/BlockscapeAccess.sol";
import "./utils/BlockscapeShared.sol";

/** 
    @title Rocketpool Staking Allocation Contract - Blockscape Validator NFT
    @author Blockscape Finance AG <info@blockscape.network>
    @notice collects staking, mints NFT in return for staker and let's backend controller 
    transfer the stake when the pool is full (currently 16 ETH) and enough RPL are available
    @notice this implementation relies on a backend controller which is a core component
    of the implementation.
*/

/**
 * @notice error message if a validator is already set
 */
error ValidatorAlreadySet(address _vali);

contract BlockscapeValidatorNFT is
    ERC1155Supply,
    ReentrancyGuard,
    BlockscapeAccess,
    BlockscapeShared
{
    /// @notice name constant used for blockexplorers (as to be lower case as per blockexplorer standards)
    string public constant name = "Blockscape Validator NFTs";

    /// @notice symbol constant used for blockexplorers (as to be lower case as per blockexplorer standards)
    string public constant symbol = "BSV";

    /// @notice Current Rocketpool Minipool Limit
    uint256 private curETHlimit = 8 ether;

    /// @dev mapping of tokenID to validator minipool address
    mapping(uint256 => address) private tokenIDtoValidator;

    /** 
        @notice each validator related vault gets its separate tokenID which depicts 
        the nft for each staker
        @dev the IPNS makes sure the nfts stay reachable via this link while 
        new nfts get added to the underlying ipfs folder
     */
    constructor()
        ERC1155(
            "https://ipfs.apps.blockscape.network/ipns/"
            "k51qzi5uqu5dhnfa4f97n7u9gq678o4dg3nfj2bg4u2yh1yzm9izzw3qdg2m0h/" // mainnet
            "{id}.json"
        )
        BlockscapeAccess(
            0xddec97be14198D8307332EbCd6421b7f08D8E1f6, // Blockscape ADJ Config 
            blockscapeRocketPoolNode, // Blockscape Rocketpool Node Mainnet
            0x97E18544e156724E4076945F10c288ecBBC94e54 //Blockscape Multi Sig Wallet
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
     * @dev the vault must be open and equal the depositing amount
     * @dev enought RPL must be staked in the rocketpool by the node
     * */
    function depositValidatorNFT() external payable {
        if (!isVaultOpen()) revert ErrorVaultState(isVaultOpen());

        if (curETHlimit != msg.value) revert IncorrectDepositValueSent();

        _setMetadataForStakeInternal(msg.value, tokenID);

        _mint(msg.sender, tokenID, 1, "");

        tokenID++;

        vaultOpen = false;
    }

    /**
        @notice this gets triggered by the backend controller when a new token is minted
        @dev the backend controller is only able to withdraw the current ETH limit
     */
    function withdrawBatch() external onlyRole(RP_BACKEND_ROLE) nonReentrant {
        if (vaultOpen) revert ErrorVaultState(vaultOpen);

        Address.sendValue(blockscapeRocketPoolNode, curETHlimit);
    }

    /**
        @notice update validator address for given token id only once after the NFT has been issued 
        and the validator was created by the backend 
        this function will only be called by the backend
        @dev works only once for a tokenID; it will reopen the vault 
        @dev emits no event by design to reduce maintenance costs
        @param _tokenID Identifier of the NFT
        @param _vali the current address of the validator
    */
    function updateValidator(
        uint256 _tokenID,
        address _vali
    ) external onlyRole(RP_BACKEND_ROLE) {
        if (address(0) != tokenIDtoValidator[_tokenID]) {
            revert ValidatorAlreadySet(tokenIDtoValidator[_tokenID]);
        }
        if (vaultOpen) revert ErrorVaultState(vaultOpen);

        tokenIDtoValidator[_tokenID] = _vali;

        vaultOpen = true;
    }

    /**
        @notice Withdraw is a two step process, first the staker has to call prepareWithdrawalProcess()
        @dev fist step used by the staker when he or she wants to unstake
        @param _tokenID which validator NFT the staker wants to unstake; 
        the backend will listen on the event and will unstake the validator. 
        The ETH value with rewards is transparantly available 
        via beacon chain explorers and will be reduced by the withdraw fee,
        which is fixed to 0.5% after one year.
     */
    function prepareWithdrawalProcess(uint256 _tokenID) external override {
        if (balanceOf(msg.sender, _tokenID) == 0)
            revert YouDontOwnThisNft(_tokenID);

        if (tokenIDToTimestamp[_tokenID] != 0)
            revert AlreadyPreparingForWithdrawal();

        uint256 elapsedTime = block.timestamp -
            tokenIDtoMetadata[_tokenID].stakedTimestamp;

        if (elapsedTime < 3 days) {
            revert PrepareWithdrawalTimelockNotReached();
        }

        tokenIDToTimestamp[_tokenID] = block.timestamp;

        uint256 curWithdrawFee = calcWithdrawFee(_tokenID, msg.sender);
        uint256 rewards = estRewardsNoMEV(_tokenID);
        emit UserRequestedWithdrawalVali(
            _tokenID,
            msg.sender,
            curWithdrawFee,
            tokenIDtoMetadata[_tokenID].stakedETH,
            rewards
        );
    }

    /**
     *  @notice used by the staker after prepareWithdrawalProcess() & the timelock has passed to withdraw the funds
     *  @dev the rewards are calculated by the backend controller and are then stored in the contract,
     *  this is needed to be able to calculate the rewards correctly including MEV rewards.
     *  @dev There off-chain calculated rewards cannot be lower than the on-chain estimated rewards.
     */
    function withdrawFunds(uint256 _tokenID) external override nonReentrant {
        if (balanceOf(msg.sender, _tokenID) == 0)
            revert YouDontOwnThisNft(_tokenID);

        if (tokenIDToTimestamp[_tokenID] == 0)
            revert NotPreparingForWithdrawal();

        uint256 elapsedTime = block.timestamp - tokenIDToTimestamp[_tokenID];

        if (elapsedTime < timelockWithdraw) {
            revert WithdrawalTimelockNotReached(
                tokenIDToTimestamp[_tokenID] + timelockWithdraw
            );
        }
        if (tokenIDToExitReward[_tokenID] < estRewardsNoMEV(_tokenID)) {
            tokenIDToExitReward[_tokenID] = estRewardsNoMEV(_tokenID);
        }

        safeTransferFrom(msg.sender, blockscapeRocketPoolNode, _tokenID, 1, "");

        Address.sendValue(
            payable(msg.sender),
            tokenIDtoMetadata[_tokenID].stakedETH +
                tokenIDToExitReward[_tokenID]
        );
        tokenIDToTimestamp[_tokenID] = 0;
    }

    /**
     * @notice this function is called by the backend controller when the UserRequestedWithdrawal is emited
     * @dev the rewards are calculated by the backend controller and are then stored in the contract,
     * this is needed to be able to calculate the rewards correctly including MEV rewards.
     * There off-chain calculated rewards cannot be lower than the on-chain estimated rewards.
     * @param _tokenID the tokenID of the validator
     * @param _calcReward the calculated rewards in wei
     *
     */
    function calcRewards(
        uint256 _tokenID,
        uint256 _calcReward
    ) public onlyRole(RP_BACKEND_ROLE) {
        tokenIDToExitReward[_tokenID] = _calcReward;
    }


    /**
     * @dev this function is only callable by our multisig wallet with ADJ_CONFIG_ROLE
     * @dev this will set the comission fee for 8 ETH minipools
     * @param _amount the new comission
     */
    function lowerRPCommFee8(
        uint256 _amount
    ) external onlyRole(ADJ_CONFIG_ROLE) {
        if (_amount >= 14) revert RPCommFee8TooHigh();
        rpComm8 = _amount;
    }

    /**
        @notice the current depositing threshold
        @return the current ETH limit in wei
    */
    function getCurrentEthLimit() public view returns (uint256) {
        return curETHlimit;
    }

    /**
        @notice how much fees would the user has to pay if he or she would unstake now
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
            uint256 secFee = (initWithdrawFee / 365 days);
            uint256 timePassed = block.timestamp -
                (tokenIDtoMetadata[_tokenID].stakedTimestamp);

            uint256 maxTime05EthReached = 30747600;
            if (timePassed >= maxTime05EthReached) {
                curWithdrawFee = 5 * 1e17;
            } else {
                curWithdrawFee = (initWithdrawFee - (secFee * timePassed));
            }
        } else {
            curWithdrawFee = 0;
        }
        return curWithdrawFee;
    }

    /**
     * @notice this function is used to get the validator address from the tokenID
     * @param _tokenID the tokenID of the NFT
     * @return the minipool address of the validator
     */
    function getValidatorAddress(
        uint256 _tokenID
    ) public view returns (address) {
        return tokenIDtoValidator[_tokenID];
    }

    /**
        @notice this function is a on-chain calculation of the rocketpool ETH rewards. 
        It does not take MEV into account & will only work correctly 
        after the Shapella/Shanghai upgrade
        @param _tokenID tokenID of the NFT, the user wants to unstake
        @return rewards in wei minus the withdraw fee
     */
    function estRewardsNoMEV(uint256 _tokenID) internal view returns (uint256) {
        uint256 balance = (address(tokenIDtoValidator[_tokenID]).balance / 4);
        uint256 balanceComm = (rpComm8 * (balance * 3)) / 100;

        uint256 wfee = ((calcWithdrawFee(_tokenID, msg.sender) * balanceComm) /
            1e19);
        return (balance + balanceComm - wfee);
    }

    /// @notice total amount of supply
    /// @return total amount of ERC-1155 tokens of the contract
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
        return
            "https://ipfs.apps.blockscape.network/ipfs/QmNzkCwFEwc4pcEYJihPzxCbjnnx1FNUDbgpmb7tpdi3ov";
    }

    /**
        @notice gets the url to the metadata of a given pool
        @param _tokenID the pool
        @return the url
     */
    function uri(
        uint256 _tokenID
    ) public pure override returns (string memory) {
        return
            string.concat(
                "https://ipfs.apps.blockscape.network/ipns/k51qzi5uqu5dhnfa4f97n7u9gq678o4dg3nfj2bg4u2yh1yzm9izzw3qdg2m0h/",
                Strings.toString(_tokenID),
                ".json"
            );
    }
}
