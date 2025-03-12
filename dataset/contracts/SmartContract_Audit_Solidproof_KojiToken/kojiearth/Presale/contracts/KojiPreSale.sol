pragma solidity ^0.5.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/crowdsale/Crowdsale.sol";
import "@openzeppelin/contracts/crowdsale/emission/AllowanceCrowdsale.sol";
import "@openzeppelin/contracts/crowdsale/validation/TimedCrowdsale.sol";
import "@openzeppelin/contracts/crowdsale/validation/CappedCrowdsale.sol";
import "@openzeppelin/contracts/access/roles/CapperRole.sol";

contract KojiCrowdSale is Crowdsale, AllowanceCrowdsale, TimedCrowdsale, CappedCrowdsale, CapperRole {  
    
   using SafeMath for uint256;

    mapping(address => uint256) private _contributions;
    mapping(address => uint256) private _caps;
    
    uint256 private _individualDefaultCap;
     
    
    constructor(
    uint256 _rate,           //000000003 = 3 billion per eth
    address payable _wallet, //where the eth goes
    IERC20 _token,           //token contract address
    address _tokenWallet,    //address holding the tokens
    uint256 _openingTime,    //start time in unix time
    uint256 _closingTime,    //end time in unix time
    uint256 individualCap,   //per wallet cap in wei
    uint256 _cap            //total sale cap in wei   
  )
        
    public 
    AllowanceCrowdsale(_tokenWallet)
    Crowdsale(_rate, _wallet, _token)
    TimedCrowdsale(_openingTime, _closingTime)
    CappedCrowdsale(_cap)
    {
         _individualDefaultCap = individualCap;
    }

    address payable owner = msg.sender;

    modifier onlyOwner() {
        require(msg.sender == owner);
    _;
    }
    
    function withdrawUnsoldTokens(address tokenAddress) onlyOwner public
    {
        require(msg.sender == owner);
        ERC20 mytoken = ERC20(tokenAddress);
        uint256 unsold = mytoken.balanceOf(address(this));
        mytoken.transfer(owner, unsold);
    }
    

    /**
     * @dev Sets a specific beneficiary's maximum contribution.
     * @param beneficiary Address to be capped
     * @param cap Wei limit for individual contribution
     */
    function setCap(address beneficiary, uint256 cap) external onlyCapper {
        _caps[beneficiary] = cap;
    }

    /**
     * @dev Returns the cap of a specific beneficiary.
     * @param beneficiary Address whose cap is to be checked
     * @return Current cap for individual beneficiary
     */
    function getCap(address beneficiary) public view returns (uint256) {
        uint256 cap = _caps[beneficiary];
        if (cap == 0) {
            cap = _individualDefaultCap;
        }
        return cap;
    }

    /**
     * @dev Returns the amount contributed so far by a specific beneficiary.
     * @param beneficiary Address of contributor
     * @return Beneficiary contribution so far
     */
    function getContribution(address beneficiary) public view returns (uint256) {
        return _contributions[beneficiary];
    }

    /**
     * @dev Extend parent behavior requiring purchase to respect the beneficiary's funding cap.
     * @param beneficiary Token purchaser
     * @param weiAmount Amount of wei contributed
     */
    function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal view {
        super._preValidatePurchase(beneficiary, weiAmount);
        // solhint-disable-next-line max-line-length
        require(_contributions[beneficiary].add(weiAmount) <= getCap(beneficiary), "KOJISale: wallet cap exceeded");
    }

    /**
     * @dev Extend parent behavior to update beneficiary contributions.
     * @param beneficiary Token purchaser
     * @param weiAmount Amount of wei contributed
     */
    function _updatePurchasingState(address beneficiary, uint256 weiAmount) internal {
        super._updatePurchasingState(beneficiary, weiAmount);
        _contributions[beneficiary] = _contributions[beneficiary].add(weiAmount);
      }

    
    
   
}

