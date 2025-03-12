// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../EIP/SafeTokenRecoverUpgradeable.sol";
import "../Extensions/IERC20SnapshotUpgradeable.sol";
import "./IUniswapV2Router02.sol";
import "./IDividenDistributor.sol";

contract DividenDistributorV1 is  
    IDividenDistributor,
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    SafeTokenRecoverUpgradeable,
    PausableUpgradeable    
{
    struct Reward {
        uint256 rewardAmount;        
        uint256 totalClaimed;
        uint256 issuedAt;
        uint256 snapshotId;  
        uint256 totalExcludedFromSupply;      
        uint8 rewardSource;  
        mapping(address => bool) isExcludedFromReward;   
        mapping(address => bool) rewardClaimed;
    }

    mapping(uint256 => Reward) public rewards;
    address[] public listExcludedFromReward;

    IUniswapV2Router02 public uniswapV2Router;    
    uint256 public lastRewardShare;   
    uint256 rewardLength;     
    address public mainToken;       
    bool private inSwap;
    bytes32 public constant REWARDER_ROLE = keccak256("REWARDER");
    
    mapping(address => bool) public isExcludedFromReward;    
    mapping(address => mapping(uint8 => uint256)) public holderToTotalClaimed; // Holder Address => Reward Source => Total Amount FTM Claimed

    event UpdateMainToken(address newMainToken);   
    event NewReward(uint256 rewardId, uint256 rewardAmount, uint256 snapshotId, uint8 rewardSource);
    event ClaimReward(uint256 indexed rewardId, uint256 rewardAmount, address indexed holder); 
    event ExcludedFromReward(address indexed holder, bool state);

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }
    
    // Initialize
    function initialize() external initializer {        

        __AccessControl_init_unchained();
        __Context_init_unchained();
        __SafeTokenRecover_init_unchained();
        __Pausable_init_unchained();

        // Setup deployer as Admin when construction
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(RESCUER_ROLE, _msgSender());


        uniswapV2Router = IUniswapV2Router02(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
        inSwap = false;
    }

    /**
     * @dev override function when contract upgraded
     */
    function _authorizeUpgrade(address newImplementation) internal override {
        require(
            newImplementation != address(0),
            "Staking: Cannot zero address"
        );
        require(
            _msgSender() == _getAdmin(),
            "Staking: Not the Owner of Contract"
        );
    } // solhint-disable-line no-empty-blocks    

    function swapAndShareReward() external onlyRole(REWARDER_ROLE) {
        require(mainToken != address(0), "DD : MAIN_TOKEN_NOT_SETTED");
        uint256 mainTokenBalance = getTokenBalance();
        
        lastRewardShare = block.timestamp;

        uint256 ethBalanceBefore = getBalance();
        
        // Swap        
        _swapTokensForEth(mainTokenBalance);

        uint256 ethBalanceAfter = getBalance();

        _createReward(ethBalanceAfter - ethBalanceBefore, 0);
    }    
    
    function shareReward() external payable onlyRole(REWARDER_ROLE) {
        require(msg.value > 0, "DD: NO_ETH_SENT");
        _createReward(msg.value, 1);
    }

    function _createReward(uint256 rewardAmount, uint8 rewardSource) internal {
        uint256 snapshotId = IERC20SnapshotUpgradeable(mainToken).snapshot();
        uint256 rewardId = rewardLength;
        Reward storage reward = rewards[rewardId];
        reward.rewardAmount = rewardAmount;
        reward.totalClaimed = 0;
        reward.issuedAt = block.timestamp;
        reward.snapshotId = snapshotId;
        reward.rewardSource = rewardSource; 
        
        uint256 totalExcluded = 0;
        for (uint8 i = 0; i < listExcludedFromReward.length; i++) {
            reward.isExcludedFromReward[listExcludedFromReward[i]] = true;
            totalExcluded += IERC20SnapshotUpgradeable(mainToken).balanceOfAt(listExcludedFromReward[i], snapshotId);
        }
        reward.totalExcludedFromSupply = totalExcluded;
                         
        rewardLength++;

        emit NewReward(rewardId, rewardAmount, snapshotId, rewardSource);
    }

    function _swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(mainToken);
        path[1] = uniswapV2Router.WETH();
        IERC20Upgradeable(mainToken).approve(address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function claimReward(uint256 rewardId) external override {
        require(_rewardExists(rewardId), "DD: REWARD_NOT_EXISTS");
        require(!rewards[rewardId].isExcludedFromReward[_msgSender()], "DD: NOT_ALLOWED_TO_CLAIM");
        require(!rewards[rewardId].rewardClaimed[_msgSender()], "DD: REWARD_HAS_CLAIMED");        
            
        uint256 rewardAmount = _claim(rewardId, _msgSender());
        _safeTransferETH(_msgSender(), rewardAmount);
        
        emit ClaimReward(rewardId, rewardAmount, _msgSender());
    }

    /**
     * @dev to claim multiple reward at once
     */
    function batchClaimReward(uint256[] calldata rewardIds) external {
        uint256 totalRewardAmount = 0;

        for (uint256 i = 0; i < rewardIds.length; i++) {
            uint256 rewardId = rewardIds[i];
            
            if(_rewardExists(rewardId) && 
                !rewards[rewardId].isExcludedFromReward[_msgSender()] && 
                !rewards[rewardId].rewardClaimed[_msgSender()]
            ) {
                 uint256 rewardAmount = _claim(rewardId, _msgSender());
                 totalRewardAmount += rewardAmount;
                emit ClaimReward(rewardId, rewardAmount, _msgSender());
            }            
        }

        if(totalRewardAmount > 0) {
            _safeTransferETH(_msgSender(), totalRewardAmount);
        }
    }

    function _claim(uint256 rewardId, address holder) internal returns (uint256){
        Reward storage reward = rewards[rewardId];    
        (uint256 holderBalance,,uint256 rewardAmount) = _calculateRewardAmount(
            reward.snapshotId,
            reward.totalExcludedFromSupply,
            reward.rewardAmount,
            holder
        );

        require(holderBalance > 0, "DD: NOT_A_HOLDER");

        reward.rewardClaimed[holder] = true;
        reward.totalClaimed += rewardAmount;
        holderToTotalClaimed[holder][reward.rewardSource] += rewardAmount;  

        return rewardAmount;
    }

    function _calculateRewardAmount(
        uint256 snapshotId,
        uint256 totalExcludedFromSupply,
        uint256 rewardAmount,
        address holder
    ) internal view returns (uint256 holderBalance, uint256 supply, uint256 calculateRewardAmount) {
        holderBalance = IERC20SnapshotUpgradeable(mainToken).balanceOfAt(holder, snapshotId);
        supply = IERC20SnapshotUpgradeable(mainToken).totalSupplyAt(snapshotId) - totalExcludedFromSupply;        
        calculateRewardAmount = rewardAmount * holderBalance / supply;
    }

    function _rewardExists(uint256 rewardId) internal view returns (bool) {
        return rewards[rewardId].issuedAt > 0;
    }

    /**
     * @dev get total amount of frock that owned by this contract
     */
    function getTokenBalance() public view returns(uint256 tokenAmount) {
        return IERC20Upgradeable(mainToken).balanceOf(address(this));
    }

    /**
     * @dev get total amount of FTM that owned by this contract
     */
    function getBalance() public view returns(uint256 balance) {
        return address(this).balance;
    }

    /**
     * @dev set main token (frock token) address
     */
    function setMainToken(address tokenAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mainToken = tokenAddress;
        emit UpdateMainToken(tokenAddress);
    }

    function _safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'DD: ETH_TRANSFER_FAILED');
    }

    /**
     * @dev to Exclude address from reward distribution
     */
    function excludedFromReward(address holder, bool state) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(isExcludedFromReward[holder] != state, "Cannot set to same state");
        _excludedFromReward(holder, state);
    }

    function _excludedFromReward(address holder, bool state) internal {
        isExcludedFromReward[holder] = state;

        if(state) {
            // Add to list
            listExcludedFromReward.push(holder);            
        } else {
            // Remove fromlist           
            for(uint256 i = 0; i < listExcludedFromReward.length ; i ++) {
                if(listExcludedFromReward[i] == holder) {
                    if(i == listExcludedFromReward.length-1) {
                        // Last element
                        listExcludedFromReward.pop();
                    } else {
                        // First or Not last element
                        listExcludedFromReward[i] = listExcludedFromReward[listExcludedFromReward.length - 1];
                        listExcludedFromReward.pop();
                    }
                    break;
                }
            }
        }

        emit  ExcludedFromReward(holder, state);
    }

    /**
     * @dev get total amount of building trade dividen
     * @dev only calculate for reward that coming from swapAndShareReward function
     */
    function buildingTradeDividendOfHolder(address holder) external view returns (uint256) {
        if(!isExcludedFromReward[holder]) {
            uint256 snapshotId = IERC20SnapshotUpgradeable(mainToken).lastSnapshotId();
            uint256 holderBalance = IERC20SnapshotUpgradeable(mainToken).balanceOfAt(holder, snapshotId);
            uint256 supply = IERC20SnapshotUpgradeable(mainToken).totalSupplyAt(snapshotId);
            uint256 currentContractBalance = getTokenBalance();
            return currentContractBalance * holderBalance / supply;
        }
        return 0;
    }

    /**
     * @dev Get list if reward id that not yet claimed by holder
     * @param holder is holder's address 
     * @param rewardSource 0 => Reward that coming from swapAndShareReward, 1 => Reward that coming from  shareReward
     */
    function getRewardIdsUnclaimed(address holder, uint8 rewardSource) public view returns (uint256[] memory) {
        uint256[] memory tempRewardIds = new uint256[](rewardLength);

        uint256 tempLength = 0;
        for(uint i = 0; i < rewardLength; i++) {
            // Reward memory reward = rewards[i];
            uint8 rewardSourceType = rewards[i].rewardSource;            
            if(rewardSourceType == rewardSource) {
                bool isRewardClaimed = rewards[i].rewardClaimed[holder];
                bool isHolderExcludedFromReward = rewards[i].isExcludedFromReward[holder];
                if(!isRewardClaimed && !isHolderExcludedFromReward) {                    
                    tempRewardIds[tempLength] = i;
                    tempLength++;
                }   
            }
        }      

        uint256[] memory rewardIds = new uint256[](tempLength);
        for(uint j = 0; j < tempLength; j++ ){
            rewardIds[j] = tempRewardIds[j];
        }

        return rewardIds;
    }

     /**
     * @dev Get total amount of reward that not yet claimed by holder
     * @param holder is holder's address 
     * @param rewardSource 0 => Reward that coming from swapAndShareReward, 1 => Reward that coming from  shareReward
     */
    function getTotalUnclaimedReward(address holder, uint8 rewardSource) external view returns (uint256 totalUnclaimedReward) {
        uint256[] memory rewardIdsUnclaimed = getRewardIdsUnclaimed(holder, rewardSource);
        for(uint i = 0 ; i < rewardIdsUnclaimed.length; i++) {
            uint256 rewardId = rewardIdsUnclaimed[i];            
            (,,uint256 rewardAmount) = _calculateRewardAmount(
                rewards[rewardId].snapshotId,
                rewards[rewardId].totalExcludedFromSupply,
                rewards[rewardId].rewardAmount,
                holder
            );
            totalUnclaimedReward += rewardAmount;
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControlUpgradeable) returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId 
        || interfaceId == type(IDividenDistributor).interfaceId
        || super.supportsInterface(interfaceId);        
    }
    
    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
