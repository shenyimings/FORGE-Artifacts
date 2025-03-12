pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@pancakeswap2/pancake-swap-core/contracts/interfaces/IPancakeFactory.sol";
import "@pancakeswap2/pancake-swap-core/contracts/interfaces/IPancakePair.sol";
import "pancakeswap-peripheral/contracts/interfaces/IPancakeRouter01.sol";
import "pancakeswap-peripheral/contracts/interfaces/IPancakeRouter02.sol";

/**
 * @title BEP20Token
 * @author AmberSoft (visit https://ambersoft.llc)
 *
 * @dev Mintable BEP20 token with burning and optional functions implemented.
 * Any address with minter role can mint new tokens.
 * For full specification of ERC-20 standard see:
 * https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
 */
contract XPSToken is Context, IERC20, Ownable {
    using SafeMath for uint256;

    address public immutable WETH;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    IPancakeRouter02 public immutable pancakeswapV2Router;
    address public immutable pancakeswapV2Pair;

    // Fees
    uint256 public _liquidityPoolFee = 20;
    uint256 public _marketingPoolFee = 70;
    uint256 public _burnFee = 5;
    uint256 public _communityRewardPoolFee = 5;

    // Main fee
    uint256 public _commonFee = 1;
    uint256 private _maxCommonFee = 5;
    uint256 public _specialFee = 5;
    uint256 private _maxSpecialFee = 10;

    // Vote config
    uint256 private _minAcceptedVotes = 3;
    uint256 private _minDeclinedVotes = 3;

    // Fee votes
    uint256 public _votedCommonFee;
    bool public _inVoteCommonFee = false;
    mapping(address => bool) public _votesCommonFee;
    address[] public _votedCommonFeeWallets;
    uint256 public _currentOffsetVoteCommonFee = 0;

    uint256 public _votedSpecialFee;
    bool public _inVoteSpecialFee = false;
    mapping(address => bool) public _votesSpecialFee;
    address[] public _votedSpecialFeeWallets;
    uint256 public _currentOffsetVoteSpecialFee = 0;

    // Pools votes
    address payable public _votedMarketingPoolWallet;
    bool public _inVoteMarketingPoolWallet = false;
    mapping(address => bool) public _votesMarketingPoolWallet;
    address[] public _votedMarketingPoolWalletWallets;
    uint256 public _currentOffsetVoteMarketingPoolWallet = 0;

    address payable public _votedCommunityRewardPoolWallet;
    bool public _inVoteCommunityRewardPoolWallet = false;
    mapping(address => bool) public _votesCommunityRewardPoolWallet;
    address[] public _votedCommunityRewardPoolWalletWallets;
    uint256 public _currentOffsetVoteCommunityRewardPoolWallet = 0;

    // Sent to pools on transaction
    bool private _swapOnTransaction = true;

    // Trigger amount to auto swap
    uint256 public _liquidityTriggerAmount = 5 * 10 ** 12; // = 5,000 tokens
    uint256 public _marketingTriggerAmount = 5 * 10 ** 12; // = 5,000 tokens
    uint256 public _communityTriggerAmount = 5 * 10 ** 12; // = 5,000 tokens

    // Current amount to swap
    uint256 public _currentLiquidityTriggerAmount = 0;
    uint256 public _currentMarketingTriggerAmount = 0;
    uint256 public _currentCommunityTriggerAmount = 0;

    // Total amount
    uint256 public _totalLiquidityTriggerAmount = 0;
    uint256 public _totalMarketingTriggerAmount = 0;
    uint256 public _totalCommunityTriggerAmount = 0;

    // Multisig wallets
    mapping(address => bool) private _multisigWallets;

    // Excluded from fee
    mapping(address => bool) private _excludedFromFee;

    // Special addresses
    mapping(address => bool) private _includedInSpecialFee;

    // Pools addresses
    address payable private _marketingPoolWallet;
    address payable private _communityRewardPoolWallet;

    // Delayed Team Reward
    address private immutable _teamWallet;
    uint256 public immutable _timeToReleaseFirstStep;
    uint256 public immutable _timeToReleaseSecondStep;
    uint256 public immutable _lockedTokensForTeam;
    uint256 public _percentFromSupplyForTeam = 15;
    uint256 public immutable _percentReleaseFirstStep = 60;
    uint256 public immutable _percentReleaseSecondStep = 40;

    bool inSwapAndLiquify;

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    
    bool inSwapAndCommunity;

    modifier lockTheSwapCommunity {
        inSwapAndCommunity = true;
        _;
        inSwapAndCommunity = false;
    }

    event SwapAndCommunity(
        uint256 tokensSwapped,
        uint256 ethReceived
    );
    
    bool inSwapAndMarketing;

    modifier lockTheSwapMarketing {
        inSwapAndMarketing = true;
        _;
        inSwapAndMarketing = false;
    }

    event SwapAndMarketing(
        uint256 tokensSwapped,
        uint256 ethReceived
    );

    constructor(
        string memory contractName,
        string memory contractSymbol,
        uint8 contractDecimals,
        uint256 initialSupply,
        address payable initialMarketingPoolWallet,
        address payable initialCommunityRewardPoolWallet,
        address routerAddress, // 0xD99D1c33F9fC3444f8101754aBC46c52416550D1 - test, 0x10ED43C718714eb63d5aA57B78B54704E256024E - main
        address contractTeamWallet
    ) public payable {
        require(initialMarketingPoolWallet != address(0), "Marketing pool wallet can't be 0");
        require(initialCommunityRewardPoolWallet != address(0), "Community Reward pool wallet can't be 0");
        require(contractTeamWallet != address(0), "Team wallet can't be 0");
        require(initialSupply >= 1000000000000000000, "Initial supply can't be less than 1000000000000000000");

        _name = contractName;
        _symbol = contractSymbol;
        _decimals = contractDecimals;
        _communityRewardPoolWallet = initialCommunityRewardPoolWallet;
        _marketingPoolWallet = initialMarketingPoolWallet;

        // Initiate multisig wallets @TODO change wallets
        _multisigWallets[0xB6FA2fA21C9fdBe4C83CCa147bDe8d73439cDb62] = true;
        _multisigWallets[0xed8004888E6A84731e8fB3E26d899b18b7EA3aE9] = true;
        _multisigWallets[0x0E665191Bd0791Fa47644D62196e2727c9a8Ab0F] = true;
        _multisigWallets[0xD1D9B3399840846F302Df0f904EC977b3AEbd7c6 ] = true;
        _multisigWallets[0xc8BB3909dF983B5a9634D1C8B0c89Cc6551D84c6] = true;

        IPancakeRouter02 _pancakeswapV2Router = IPancakeRouter02(routerAddress);
        WETH = _pancakeswapV2Router.WETH();

        // Create a Pancake pair for this new token
        pancakeswapV2Pair = IPancakeFactory(_pancakeswapV2Router.factory())
            .createPair(address(this), _pancakeswapV2Router.WETH());

        // set the rest of the contract variables
        pancakeswapV2Router = _pancakeswapV2Router;

        excludeFromFee(address(this));
        excludeFromFee(_msgSender());
        excludeFromFee(routerAddress);

        _teamWallet = contractTeamWallet;
        _lockedTokensForTeam = (initialSupply.mul(_percentFromSupplyForTeam)).div(100);
        _timeToReleaseFirstStep = block.timestamp + 243 days;
        _timeToReleaseSecondStep = block.timestamp + 365 days;
        // set tokenOwnerAddress as owner of initial supply, more tokens can be minted later
        _mint(_msgSender(), initialSupply.sub((initialSupply.mul(_percentFromSupplyForTeam)).div(100)));
        // commented statement below because _mint is emitting Transfer event already
        // emit Transfer(address(0), _msgSender(), initialSupply);
    }

    function releaseTeamFirstStep() external {
        require(block.timestamp >= _timeToReleaseFirstStep, "It's not time yet");

        uint256 releaseAmount = (_lockedTokensForTeam.mul(_percentReleaseFirstStep)).div(100);
        _mint(_teamWallet, releaseAmount);
        // commented statement below because _mint is emitting Transfer event already
        // emit Transfer(address(0), _teamWallet, releaseAmount);
    }

    function releaseTeamSecondStep() external {
        require(block.timestamp >= _timeToReleaseSecondStep, "It's not time yet");

        uint256 releaseAmount = (_lockedTokensForTeam.mul(_percentReleaseSecondStep)).div(100);
        _mint(_teamWallet, releaseAmount);
        // commented statement below because _mint is emitting Transfer event already
        // emit Transfer(address(0), _teamWallet, releaseAmount);
    }

    // Vote methods

    // Common Fee
    function startVoteForCommonFee(uint256 newCommonFee) external {
        require(_multisigWallets[_msgSender()], "Only multisig wallets can start vote");
        require(!_inVoteCommonFee, "Vote is already started");
        require(newCommonFee <= 5, "Maximum fee is 5");

        _inVoteCommonFee = true;
        _votedCommonFee = newCommonFee;
        _votesCommonFee[_msgSender()] = true;
        _votedCommonFeeWallets.push(_msgSender());
    }

    function voteForCommonFee(bool vote) external {
        require(_multisigWallets[_msgSender()], "Only multisig wallets can voting");
        require(_inVoteCommonFee, "Voting hasn't started");

        bool isInVote = false;
        for (uint i = _currentOffsetVoteCommonFee; i < _votedCommonFeeWallets.length; i++) {
            if(_votedCommonFeeWallets[i] == _msgSender()) {
                isInVote = true;
            }
        }
        require(!isInVote, "You can vote only once");

        _votesCommonFee[_msgSender()] = vote;
        _votedCommonFeeWallets.push(_msgSender());

        uint8 currentVoteStatus = checkVotingCommonFee();
        if(currentVoteStatus < 2) {
            endCommonFeeVote(currentVoteStatus == 1);
        }
    }

    function checkVotingCommonFee() internal returns (uint8) {
        uint256 acceptedVotes = 0;
        uint256 declinedVotes = 0;

        for (uint i = _currentOffsetVoteCommonFee; i < _votedCommonFeeWallets.length; i++) {
            address voteWallet = _votedCommonFeeWallets[i];
            if (_votesCommonFee[voteWallet]) {
                acceptedVotes = acceptedVotes.add(1);
            } else {
                declinedVotes = declinedVotes.add(1);
            }
        }

        if (acceptedVotes >= _minAcceptedVotes) {
            return 1;
        }

        if (declinedVotes >= _minDeclinedVotes) {
            return 0;
        }

        return 2;
    }

    function endCommonFeeVote(bool decision) internal {
        if(decision) {
            _commonFee = _votedCommonFee;
        }

        // set to default
        _votedCommonFee = 0;
        _inVoteCommonFee = false;
        for (uint i = _currentOffsetVoteCommonFee; i < _votedCommonFeeWallets.length; i++) {
            address voteWallet = _votedCommonFeeWallets[i];
            delete _votesCommonFee[voteWallet];
            delete _votedCommonFeeWallets[i];
        }
        _currentOffsetVoteCommonFee = _votedCommonFeeWallets.length;
    }

    // Special fee
    function startVoteForSpecialFee(uint256 newSpecialFee) external {
        require(_multisigWallets[_msgSender()], "Only multisig wallets can start vote");
        require(!_inVoteSpecialFee, "Vote is already started");
        require(newSpecialFee <= 10, "Maximum fee is 10");

        _inVoteSpecialFee = true;
        _votedSpecialFee = newSpecialFee;
        _votesSpecialFee[_msgSender()] = true;
        _votedSpecialFeeWallets.push(_msgSender());
    }

    function voteForSpecialFee(bool vote) external {
        require(_multisigWallets[_msgSender()], "Only multisig wallets can voting");
        require(_inVoteSpecialFee, "Voting hasn't started");

        bool isInVote = false;
        for (uint i = _currentOffsetVoteSpecialFee; i < _votedSpecialFeeWallets.length; i++) {
            if(_votedSpecialFeeWallets[i] == _msgSender()) {
                isInVote = true;
            }
        }
        require(!isInVote, "You can vote only once");

        _votesSpecialFee[_msgSender()] = vote;
        _votedSpecialFeeWallets.push(_msgSender());

        uint8 currentVoteStatus = checkVotingSpecialFee();
        if(currentVoteStatus < 2) {
            endSpecialFeeVote(currentVoteStatus == 1);
        }
    }

    function checkVotingSpecialFee() internal returns (uint8) {
        uint256 acceptedVotes = 0;
        uint256 declinedVotes = 0;

        for (uint i = _currentOffsetVoteSpecialFee; i < _votedSpecialFeeWallets.length; i++) {
            address voteWallet = _votedSpecialFeeWallets[i];
            if (_votesSpecialFee[voteWallet]) {
                acceptedVotes = acceptedVotes.add(1);
            } else {
                declinedVotes = declinedVotes.add(1);
            }
        }

        if (acceptedVotes >= _minAcceptedVotes) {
            return 1;
        }

        if (declinedVotes >= _minDeclinedVotes) {
            return 0;
        }

        return 2;
    }

    function endSpecialFeeVote(bool decision) internal {
        if(decision) {
            _specialFee = _votedSpecialFee;
        }

        // set to default
        _votedSpecialFee = 0;
        _inVoteSpecialFee = false;
        for (uint i = _currentOffsetVoteSpecialFee; i < _votedSpecialFeeWallets.length; i++) {
            address voteWallet = _votedSpecialFeeWallets[i];
            delete _votesSpecialFee[voteWallet];
            delete _votedSpecialFeeWallets[i];
        }
        _currentOffsetVoteSpecialFee = _votedSpecialFeeWallets.length;
    }
    
    // Marketing wallet
    function startVoteForMarketingPoolWallet(address payable newMarketingPoolWallet) external {
        require(newMarketingPoolWallet != address(0), "Marketing pool wallet can't be 0");
        require(_multisigWallets[_msgSender()], "Only multisig wallets can start vote");
        require(!_inVoteMarketingPoolWallet, "Vote is already started");

        _inVoteMarketingPoolWallet = true;
        _votedMarketingPoolWallet = newMarketingPoolWallet;
        _votesMarketingPoolWallet[_msgSender()] = true;
        _votedMarketingPoolWalletWallets.push(_msgSender());
    }

    function voteForMarketingPoolWallet(bool vote) external {
        require(_multisigWallets[_msgSender()], "Only multisig wallets can voting");
        require(_inVoteMarketingPoolWallet, "Voting hasn't started");

        bool isInVote = false;
        for (uint i = _currentOffsetVoteMarketingPoolWallet; i < _votedMarketingPoolWalletWallets.length; i++) {
            if(_votedMarketingPoolWalletWallets[i] == _msgSender()) {
                isInVote = true;
            }
        }
        require(!isInVote, "You can vote only once");

        _votesMarketingPoolWallet[_msgSender()] = vote;
        _votedMarketingPoolWalletWallets.push(_msgSender());

        uint8 currentVoteStatus = checkVotingMarketingPoolWallet();
        if(currentVoteStatus < 2) {
            endMarketingPoolWalletVote(currentVoteStatus == 1);
        }
    }

    function checkVotingMarketingPoolWallet() internal returns (uint8) {
        uint256 acceptedVotes = 0;
        uint256 declinedVotes = 0;

        for (uint i = _currentOffsetVoteMarketingPoolWallet; i < _votedMarketingPoolWalletWallets.length; i++) {
            address voteWallet = _votedMarketingPoolWalletWallets[i];
            if (_votesMarketingPoolWallet[voteWallet]) {
                acceptedVotes = acceptedVotes.add(1);
            } else {
                declinedVotes = declinedVotes.add(1);
            }
        }

        if (acceptedVotes >= _minAcceptedVotes) {
            return 1;
        }

        if (declinedVotes >= _minDeclinedVotes) {
            return 0;
        }

        return 2;
    }

    function endMarketingPoolWalletVote(bool decision) internal {
        if(decision) {
            _marketingPoolWallet = _votedMarketingPoolWallet;
        }

        // set to default
        _inVoteMarketingPoolWallet = false;
        for (uint i = _currentOffsetVoteMarketingPoolWallet; i < _votedMarketingPoolWalletWallets.length; i++) {
            address voteWallet = _votedMarketingPoolWalletWallets[i];
            delete _votesMarketingPoolWallet[voteWallet];
            delete _votedMarketingPoolWalletWallets[i];
        }

        _currentOffsetVoteMarketingPoolWallet = _votedMarketingPoolWalletWallets.length;
    }
    
    // Community reward wallet
    function startVoteForCommunityRewardPoolWallet(address payable newCommunityRewardPoolWallet) external {
        require(newCommunityRewardPoolWallet != address(0), "Community reward pool wallet can't be 0");
        require(_multisigWallets[_msgSender()], "Only multisig wallets can start vote");
        require(!_inVoteCommunityRewardPoolWallet, "Vote is already started");

        _inVoteCommunityRewardPoolWallet = true;
        _votedCommunityRewardPoolWallet = newCommunityRewardPoolWallet;
        _votesCommunityRewardPoolWallet[_msgSender()] = true;
        _votedCommunityRewardPoolWalletWallets.push(_msgSender());
    }

    function voteForCommunityRewardPoolWallet(bool vote) external {
        require(_multisigWallets[_msgSender()], "Only multisig wallets can voting");
        require(_inVoteCommunityRewardPoolWallet, "Voting hasn't started");

        bool isInVote = false;
        for (uint i = _currentOffsetVoteCommunityRewardPoolWallet; i < _votedCommunityRewardPoolWalletWallets.length; i++) {
            if(_votedCommunityRewardPoolWalletWallets[i] == _msgSender()) {
                isInVote = true;
            }
        }
        require(!isInVote, "You can vote only once");

        _votesCommunityRewardPoolWallet[_msgSender()] = vote;
        _votedCommunityRewardPoolWalletWallets.push(_msgSender());

        uint8 currentVoteStatus = checkVotingCommunityRewardPoolWallet();
        if(currentVoteStatus < 2) {
            endCommunityRewardPoolWalletVote(currentVoteStatus == 1);
        }
    }

    function checkVotingCommunityRewardPoolWallet() internal returns (uint8) {
        uint256 acceptedVotes = 0;
        uint256 declinedVotes = 0;

        for (uint i = _currentOffsetVoteCommunityRewardPoolWallet; i < _votedCommunityRewardPoolWalletWallets.length; i++) {
            address voteWallet = _votedCommunityRewardPoolWalletWallets[i];
            if (_votesCommunityRewardPoolWallet[voteWallet]) {
                acceptedVotes = acceptedVotes.add(1);
            } else {
                declinedVotes = declinedVotes.add(1);
            }
        }

        if (acceptedVotes >= _minAcceptedVotes) {
            return 1;
        }

        if (declinedVotes >= _minDeclinedVotes) {
            return 0;
        }

        return 2;
    }

    function endCommunityRewardPoolWalletVote(bool decision) internal {
        if(decision) {
            _communityRewardPoolWallet = _votedCommunityRewardPoolWallet;
        }

        // set to default
        _inVoteCommunityRewardPoolWallet = false;
        for (uint i = _currentOffsetVoteCommunityRewardPoolWallet; i < _votedCommunityRewardPoolWalletWallets.length; i++) {
            address voteWallet = _votedCommunityRewardPoolWalletWallets[i];
            delete _votesCommunityRewardPoolWallet[voteWallet];
            delete _votedCommunityRewardPoolWalletWallets[i];
        }

        _currentOffsetVoteCommunityRewardPoolWallet = _votedCommunityRewardPoolWalletWallets.length;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
        uint256 totalSendAmount = amount;

        // Only if address is not excluded from fee
        if(!isExcludedFromFee(_msgSender())) {
            uint256 feeAmount = 0;
            if(isIncludedInSpecialFee(_msgSender())) {
                // Special fee
                feeAmount = (totalSendAmount.mul(_specialFee)).div(100);
            } else {
                // Common fee
                feeAmount = (totalSendAmount.mul(_commonFee)).div(100);
            }
            uint256 liquidityPoolAmount = (feeAmount.mul(_liquidityPoolFee)).div(100);
            uint256 marketingPoolAmount = (feeAmount.mul(_marketingPoolFee)).div(100);
            uint256 burnAmount = (feeAmount.mul(_burnFee)).div(100);
            uint256 communityRewardPoolAmount = (feeAmount.mul(_communityRewardPoolFee)).div(100);

            totalSendAmount = totalSendAmount
                .sub(liquidityPoolAmount)
                .sub(marketingPoolAmount)
                .sub(burnAmount)
                .sub(communityRewardPoolAmount);

            // Burn
            _burn(address(this), burnAmount);
            
            // Community Reward Pool
            _currentCommunityTriggerAmount = _currentCommunityTriggerAmount.add(communityRewardPoolAmount);
            _totalCommunityTriggerAmount = _totalCommunityTriggerAmount.add(communityRewardPoolAmount);
            
            // Marketing Pool
            _currentMarketingTriggerAmount = _currentMarketingTriggerAmount.add(marketingPoolAmount);
            _totalMarketingTriggerAmount = _totalMarketingTriggerAmount.add(marketingPoolAmount);
            
            // Liquidity Pool
            _currentLiquidityTriggerAmount = _currentLiquidityTriggerAmount.add(liquidityPoolAmount);
            _totalLiquidityTriggerAmount = _totalLiquidityTriggerAmount.add(liquidityPoolAmount);
            
            if(_swapOnTransaction) {
                if(_currentCommunityTriggerAmount >= _communityTriggerAmount) {
                    swapAndCommunity(_currentCommunityTriggerAmount);
                    _currentCommunityTriggerAmount = 0;
                }
                
                if(_currentMarketingTriggerAmount >= _marketingTriggerAmount) {
                    swapAndMarketing(_currentMarketingTriggerAmount);
                    _currentMarketingTriggerAmount = 0;                    
                }
                
                if(_currentLiquidityTriggerAmount >= _liquidityTriggerAmount) {
                    swapAndLiquify(_currentLiquidityTriggerAmount);
                    _currentLiquidityTriggerAmount = 0;
                }
            }
        }

        _balances[recipient] = _balances[recipient].add(totalSendAmount);
        emit Transfer(sender, recipient, amount);
    }

    // to recieve ETH from pancakeswapV2Router when swaping
    receive() external payable {}

    /**
    * Evaluates whether address is a contract and exists.
    */
    function isContract(address addr) view private returns (bool) {
        uint size;
        assembly {size := extcodesize(addr)}
        return size > 0;
    }

    function swapAndCommunity(uint256 amount) internal lockTheSwapCommunity {
        // capture the contract's current ETH balance.
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(amount);

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // Send
        if (_communityRewardPoolWallet.send(newBalance))
        {
            emit SwapAndCommunity(amount, newBalance);
        }
        else
        {
            revert();
        }
    }
    
    function swapAndMarketing(uint256 amount) internal lockTheSwapMarketing {
        // capture the contract's current ETH balance.
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(amount);

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // Send
        if ( _marketingPoolWallet.send(newBalance) )
        {
            emit SwapAndMarketing(amount, newBalance);
        }
        else
        {
            revert();
        }
    }
    
    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        //ETH
        uint256 otherHalf = contractTokenBalance.sub(half);
        //BNB

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half);
        // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to Pancake
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the Pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeswapV2Router.WETH();

        _approve(address(this), address(pancakeswapV2Router), tokenAmount);

        // make the swap
        pancakeswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(pancakeswapV2Router), tokenAmount);

        // add the liquidity
        pancakeswapV2Router.addLiquidityETH{value : ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    function excludeFromFee(address account) public onlyOwner {
        _excludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _excludedFromFee[account] = false;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _excludedFromFee[account];
    }

    // special fee methods
    function includeInSpecialFee(address account) public onlyOwner {
        _includedInSpecialFee[account] = true;
    }

    function excludeFromSpecialFee(address account) public onlyOwner {
        _includedInSpecialFee[account] = false;
    }

    function isIncludedInSpecialFee(address account) public view returns (bool) {
        return _includedInSpecialFee[account];
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {BEP20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IBEP20-balanceOf} and {IBEP20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IBEP20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IBEP20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IBEP20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IBEP20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IBEP20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IBEP20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {BEP20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IBEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IBEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
        return true;
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "BEP20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "BEP20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "BEP20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}