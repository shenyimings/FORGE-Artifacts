// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IPair.sol";
import "./interfaces/IBribe.sol";
import "./interfaces/IMaGaugeStruct.sol";
import "./interfaces/IERC20s.sol";
import "./interfaces/IMaArtProxy.sol";
import "./libraries/Math.sol";



interface IGaugeFactory {
    function gaugeOwner() external view returns(address gaugeOwner);
}

contract CLMaGaugeV2Upgradeable is
    ReentrancyGuardUpgradeable,
    ERC721EnumerableUpgradeable
{
    using SafeERC20 for IERC20;

    bool public isForPair;
    bool public emergency;

    IERC20 public rewardToken;
    IERC20 public _VE;
    IERC20 public TOKEN;

    address public DISTRIBUTION;
    address public internal_bribe;
    address public external_bribe;
    address public gaugeFactory;

    uint private MATURITY_PRECISION;
    uint public DURATION;
    uint private WEIGHTS_MAX_POINTS;
    uint private MAX_SPLIT_WEIGHTS;
    uint private ENTRY_CALCULATION_PRECISION;

    uint private maturityIncrement;
    uint public periodFinish;
    uint public rewardRate;
    uint public lastUpdateTime;
    uint public rewardPerTokenStored;

    uint public fees0;
    uint public fees1;

    string public constant version = "1.0.0";

    uint public tokenId;

    mapping(uint => uint) public idRewardPerTokenPaid;
    mapping(uint => uint) public rewards;

    uint public _lpTotalSupplyPreLimit;
    uint public _lpTotalSupplyPostLimit;

    uint private _totalWeight;
    uint public _lastTotalWeightUpdateTime;
    uint public _weightIncrement;

    mapping(uint => uint) private _lpBalances;
    mapping(uint => uint) public _positionEntries;
    mapping(uint => uint) private _positionLastWeights;

    mapping(uint => uint) public _epochs;
    uint public LP_LAST_EPOCH_ID;
    uint private LP_EPOCH_DURATION;
    uint private LP_EPOCH_COUNT;
    uint private _lastLpUpdateInEpoch;
    mapping(uint => uint) private _nftToEpochIds;

    event RewardAdded(uint reward);
    event Deposit(address indexed user, uint amount);
    event Withdraw(address indexed user, uint amount);
    event Harvest(address indexed user, uint reward);
    event ClaimFees(address indexed from, uint claimed0, uint claimed1);

    event Split(address indexed user, uint id);
    event Merge(address indexed user, uint fromId, uint toId);
    event Increase(address indexed user, uint id, uint oldAmount, uint newAmount);

    event DistributionSet(address distribution);
    event InternalBribeSet(address bribe);
    event EmergencyModeSet(bool isEmergency);

    modifier updateTotalWeight() {
        _updateTotalWeight();
        _;
    }

    ///@dev the rewards are calculated based on total weight
    modifier updateReward(uint _maNFTId) {
        _updateReward(_maNFTId);
        _;
    }

    modifier onlyDistribution() {
        require(
            _msgSender() == DISTRIBUTION,
            "Caller is not RewardsDistribution contract"
        );
        _;
    }

    modifier isNotEmergency() {
        require(emergency == false);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _rewardToken,
        address _ve,
        address _token,
        address _distribution,
        address _internal_bribe,
        address _external_bribe,
        bool _isForPair
    ) public initializer {
        __ReentrancyGuard_init();
        if ( _rewardToken == address(0) ) {
            return;
        }
        gaugeFactory = msg.sender;
        rewardToken = IERC20(_rewardToken);     // main reward
        _VE = IERC20(_ve);                      // vested
        TOKEN = IERC20(_token);                 // underlying (LP)
        DISTRIBUTION = _distribution;           // distro address (voter)
        DURATION = 7 * 86400;                   // distro time
        MATURITY_PRECISION = 1e18;
        WEIGHTS_MAX_POINTS = 10000;             // BPS weights, 1 point = 0.01%
        MAX_SPLIT_WEIGHTS = 50;                 // max split weights positions to avoid out of gas
        ENTRY_CALCULATION_PRECISION = 1e18;     // entry calculation precision for merge/increase

        maturityIncrement = 3628800;            // 6 weeks
        _initializeEpochs(86400 * 3);           // 3 days epoch

        internal_bribe = _internal_bribe;       // lp fees goes here
        external_bribe = _external_bribe;       // bribe fees goes here

        isForPair = _isForPair;                 // pair boolean, if false no claim_fees

        emergency = false;                      // emergency flag

        //set NFT info:
    
        string memory _name = string(
            abi.encodePacked(
                "MaturityV2 NFT: ",
                IPair(_token).name()
            )
        );
        string memory _symbol = string(
            abi.encodePacked(
                "maNFTV2_",
                IPair(_token).symbol()
            )
        );
        __ERC721_init(_name, _symbol);
        tokenId = 1;
        emit Transfer(address(0), address(this), 0);

        
    }

    /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    ONLY OWNER
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */

    modifier onlyOwner() {
        require(msg.sender == IGaugeFactory(gaugeFactory).gaugeOwner());
        _;
    }

    ///@notice set distribution address (should be voter)
    function setDistribution(address _distribution) external onlyOwner {
        require(_distribution != address(0), "zero addr");
        require(_distribution != DISTRIBUTION, "same addr");
        DISTRIBUTION = _distribution;
        emit DistributionSet(DISTRIBUTION);
    }

    ///@notice set new internal bribe contract (where to send fees)
    function setInternalBribe(address _int) external onlyOwner {
        require(_int != address(0), "zero");
        internal_bribe = _int;
        emit InternalBribeSet(internal_bribe);
    }

    function activateEmergencyMode() external onlyOwner {
        require(emergency == false);
        emergency = true;
        emit EmergencyModeSet(emergency);
    }

    function stopEmergencyMode() external onlyOwner {
        require(emergency);
        emergency = false;
        emit EmergencyModeSet(emergency);
    }

    /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    VIEW FUNCTIONS
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */

    function totalWeight() external view returns (uint) {
        return _totalWeight;
    }

    function maNFTWeight(uint _maNFTId) external view returns (uint) {
        return _lpBalances[_maNFTId] * _maturityMultiplier(_maNFTId);
    }

    ///@notice total supply held
    function lpTotalSupply() public view returns (uint) {
        return _lpTotalSupplyPreLimit + _lpTotalSupplyPostLimit;
    }

    ///@notice balance of a user
    function lpBalanceOfUser(
        address account
    ) external view returns (uint amount) {
        uint[] memory tokenIds = tokensOfOwner(account);
        uint len = tokenIds.length;

        for (uint i; i < len; i++) {
            amount += _lpBalances[tokenIds[i]];
        }
    }

    ///@notice Weight of a user on this pool
    function weightOfUser(
        address account
    ) external view returns (uint amount) {
        uint[] memory tokenIds = tokensOfOwner(account);
        uint len = tokenIds.length;

        for (uint i; i < len; i++) {
            amount += _lpBalances[tokenIds[i]] * _maturityMultiplier(tokenIds[i]);
        }
    }

    function lpBalanceOfmaNFT(uint _maNFTId) external view returns (uint) {
        return _lpBalances[_maNFTId];
    }

    ///@notice last time reward
    function lastTimeRewardApplicable() public view returns (uint) {
        return Math.min(block.timestamp, periodFinish);
    }

	    ///@notice  reward for a single token	
    ///@dev total weight is used instead of LP total supply	
    function rewardPerToken() public view returns (uint) {	
        if (_totalWeight == 0) {	
            return rewardPerTokenStored;	
        } else {	
            uint weightWithoutPrecision = _totalWeight / MATURITY_PRECISION;	
            require(weightWithoutPrecision > 0, "Incorrect weight");	
            	
            return	
                rewardPerTokenStored +	
                (((lastTimeRewardApplicable() - lastUpdateTime) *	
                    rewardRate *	
                    1e18) / weightWithoutPrecision);	
        }	
    }

    ///@notice see earned rewards for nft
    function earned(uint _maNFTId) public view returns (uint) {
        uint currentPositionWeight = _lpBalances[_maNFTId] * _maturityMultiplier(_maNFTId);
        uint averagePosition = (_positionLastWeights[_maNFTId] + currentPositionWeight) / 2;

        return
            ((averagePosition *
                (rewardPerToken() - idRewardPerTokenPaid[_maNFTId])) / 1e18) /
            MATURITY_PRECISION +
            rewards[_maNFTId];
    }

    ///@notice see earned rewards for user
    function earned(address _user) public view returns (uint amount) {

        uint[] memory tokenIds = tokensOfOwner(_user);
        uint len = tokenIds.length;

        for (uint i; i < len; i++) {
            amount += earned(tokenIds[i]);
        }
        
    }

    ///@notice get total reward for the duration
    function rewardForDuration() external view returns (uint) {
        return rewardRate * DURATION;
    }

    function _periodFinish() external view returns (uint) {
        return periodFinish;
    }

    /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    USER INTERACTION
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */

    ///@notice deposit all LP TOKEN of _msgSender()
    function depositAll() external returns (uint _maNFTId) {
        uint amount = TOKEN.balanceOf(_msgSender());
        TOKEN.safeTransferFrom(_msgSender(), address(this), amount);

        _maNFTId = _deposit(amount, _msgSender());
    }

    ///@notice deposit amount LP TOKEN
    function deposit(uint amount) external returns (uint _maNFTId) {
        TOKEN.safeTransferFrom(_msgSender(), address(this), amount);

        _maNFTId = _deposit(amount, _msgSender());
    }

    ///@notice deposit amount LP TOKEN from msg.sender to _to
    function depositTo(
        uint amount,
        address _to
    ) external returns (uint _maNFTId) {
        TOKEN.safeTransferFrom(_msgSender(), address(this), amount);

        _maNFTId = _deposit(amount, _to);
    }

        ///@notice deposit amount LP TOKEN from msg.sender to _to
    function depositFromMigration(
        uint amount,
        address _to,
        uint entry
    ) external nonReentrant isNotEmergency updateTotalWeight updateReward(tokenId) returns (uint _maNFTId) {
        require( msg.sender == address(0x2157033ee7b0c9db90fbE879daE50B2FE26aD497), "not the migrator contract");
        require(amount > 0, "deposit(Gauge): cannot stake 0");
        TOKEN.safeTransferFrom(_msgSender(), address(this), amount);

        _maNFTId = tokenId;
        _mint(_to, _maNFTId);
        tokenId++;

        uint maturityAmount = _maturityMultiplierFromEntry(entry);
        
        _addToPosition(_maNFTId, amount, maturityAmount, entry);
        _positionEntries[_maNFTId] = entry;
        
        emit Deposit(_to, amount);
        
    }

    function _maturityMultiplierFromEntry(uint _entry) internal view returns (uint) {
        uint maturity = block.timestamp - _entry;
        if (maturity >= 2 * maturityIncrement) return MATURITY_PRECISION * 3;
        else return MATURITY_PRECISION +
            (maturity * MATURITY_PRECISION) /
            maturityIncrement;
    
    }

    ///@notice deposit internal
    ///@dev here a mapping should be created to have in mind the time the tokenId was last updated
    ///     and a mapping to know the maturity of this tokenId
    function _deposit(
        uint amount,
        address account
    )
        internal
        nonReentrant
        isNotEmergency
        updateTotalWeight
        updateReward(tokenId)
        returns (uint _maNFTId)
    {
        require(amount > 0, "deposit(Gauge): cannot stake 0");

        _maNFTId = tokenId;
        _mint(account, _maNFTId);
        tokenId++;

        uint entry = block.timestamp;

        _addToPosition(_maNFTId, amount, 1 * MATURITY_PRECISION, entry);
        _positionEntries[_maNFTId] = entry;
        
        emit Deposit(account, amount);
    }

    ///@notice withdraw all token
    function withdrawAll() external {
        uint[] memory tokenIds = tokensOfOwner(_msgSender());
        uint len = tokenIds.length;
        for (uint i; i < len; i++) {
            getReward(tokenIds[i]);
            _withdraw(tokenIds[i]);
        }
    }

    ///@notice withdraw a certain amount of TOKEN
    function withdraw(uint _maNFTId) external {
        getReward(_maNFTId);
        _withdraw(_maNFTId);
    }

    ///@notice withdraw internal
    ///@dev  lastUpdate mapping should update
    ///      maturity mapping should update
    function _withdraw(
        uint _maNFTId
    ) internal nonReentrant isNotEmergency updateTotalWeight updateReward(_maNFTId) {
        require(
            _isApprovedOrOwner(_msgSender(), _maNFTId),
            "maNFT: caller is not token owner or approved"
        );

        uint amount = _lpBalances[_maNFTId];

        require(amount > 0, "Cannot withdraw 0");
        require(lpTotalSupply() - amount >= 0, "supply < 0");

       _removeFromPosition(
            _maNFTId,
            amount,
            _maturityMultiplier(_maNFTId)
        );
        _positionEntries[_maNFTId] = 0;
        _nftToEpochIds[_maNFTId] = 0;
        TOKEN.safeTransfer(_ownerOf(_maNFTId), amount);

        _burn(_maNFTId);

        emit Withdraw(_msgSender(), amount);
    }

    function increase(
        uint _maNFTId,
        uint amount
    ) external nonReentrant isNotEmergency updateTotalWeight updateReward(_maNFTId) {
        require(
            _isApprovedOrOwner(_msgSender(), _maNFTId),
            "maNFT: caller is not token owner or approved"
        );

        TOKEN.safeTransferFrom(_msgSender(), address(this), amount);

        uint oldAmount = _lpBalances[_maNFTId];
        uint oldMultiplier = _maturityMultiplier(_maNFTId);

        uint oldEntry = _positionEntries[_maNFTId];
        uint newEntry = _getNewEntry(oldEntry, block.timestamp, oldAmount, amount);
        _positionEntries[_maNFTId] = newEntry;

        uint newAmount = _lpBalances[_maNFTId] + amount;
        uint newMultiplier = _maturityMultiplier(_maNFTId);
        
        _removeFromPosition(_maNFTId, oldAmount, oldMultiplier);
        _addToPosition(_maNFTId, newAmount, newMultiplier, newEntry);

        emit Increase(_msgSender(), _maNFTId, oldAmount, newAmount);
    }

    function merge(
        uint _maNFTIdFrom,
        uint _maNFTIdTo
    )
        external
        nonReentrant
        isNotEmergency
        updateTotalWeight
        updateReward(_maNFTIdFrom)
        updateReward(_maNFTIdTo)
    {
        require(_maNFTIdFrom != _maNFTIdTo, "Can't merge the same token");
        require(
            _isApprovedOrOwner(_msgSender(), _maNFTIdFrom),
            "maNFT: caller is not token owner or approved"
        );
        require(
            _isApprovedOrOwner(_msgSender(), _maNFTIdTo),
            "maNFT: caller is not token owner or approved"
        );

        _getReward(_maNFTIdFrom);

        uint oldAmountTo = _lpBalances[_maNFTIdTo];
        uint oldMultiplierTo = _maturityMultiplier(_maNFTIdTo);
        uint oldEntryTo = _positionEntries[_maNFTIdTo];

        uint newAmountTo = _lpBalances[_maNFTIdTo] + _lpBalances[_maNFTIdFrom];
        uint newEntryTo = _getNewEntry(oldEntryTo, _positionEntries[_maNFTIdFrom], oldAmountTo, _lpBalances[_maNFTIdFrom]);
        _positionEntries[_maNFTIdTo] = newEntryTo;
        uint newMultiplierTo = _maturityMultiplier(_maNFTIdTo);

        _removeFromPosition(
            _maNFTIdFrom,
            _lpBalances[_maNFTIdFrom],
            _maturityMultiplier(_maNFTIdFrom)
        );

        _removeFromPosition(
            _maNFTIdTo,
            oldAmountTo,
            oldMultiplierTo
        );
        _addToPosition(_maNFTIdTo, newAmountTo, newMultiplierTo, newEntryTo);

        _burn(_maNFTIdFrom);
        _positionEntries[_maNFTIdFrom] = 0;
        _nftToEpochIds[_maNFTIdFrom] = 0;
        emit Merge(_msgSender(), _maNFTIdFrom, _maNFTIdTo);
    }

    function split(
        uint _maNFTId,
        uint[] calldata weights
    ) external nonReentrant isNotEmergency updateTotalWeight updateReward(_maNFTId) {
        require(
            _isApprovedOrOwner(_msgSender(), _maNFTId),
            "maNFT: caller is not token owner or approved"
        );

        _getReward(_maNFTId);

        // limit the weights length to avoid out of gas
        require(weights.length <= MAX_SPLIT_WEIGHTS, "Max splitted positions exceeded");

        uint weightsSum = 0;

        for (uint i; i < weights.length; i++) {
            weightsSum += weights[i];

            uint splitAmount = (weights[i] * _lpBalances[_maNFTId]) / WEIGHTS_MAX_POINTS;
            require(splitAmount > 0, "deposit(Gauge): cannot stake 0");
            uint _newMANFTId = tokenId;
            _mint(_msgSender(), _newMANFTId); // potentially, use ownerOf(_maNFTId)
            tokenId++;

            _updateReward(_newMANFTId);

            _lpBalances[_newMANFTId] = splitAmount;
            _positionEntries[_newMANFTId] = _positionEntries[_maNFTId];
            _nftToEpochIds[_newMANFTId] = _nftToEpochIds[_maNFTId];
            _positionLastWeights[_newMANFTId] = _positionLastWeights[_maNFTId];
        }

        // bps accuracy is used for e.g.
        require(weightsSum == WEIGHTS_MAX_POINTS, "Invalid weights sum"); 

        // total weight doesn't change as liquidity and maturity didn't change
        _lpBalances[_maNFTId] = 0;
        _positionEntries[_maNFTId] = 0;
        _positionLastWeights[_maNFTId] = 0;
        _nftToEpochIds[_maNFTId] = 0;

        _burn(_maNFTId);
        
        emit Split(_msgSender(), _maNFTId); // potentially, use owner of nft
    }

    function emergencyWithdrawAll() external {
        uint[] memory tokenIds = tokensOfOwner(_msgSender());
        uint len = tokenIds.length;
        for (uint i; i < len; i++) {
            emergencyWithdraw(tokenIds[i]);
        }
    }

    function emergencyWithdraw(uint _maNFTId) public updateTotalWeight nonReentrant {
        require(emergency);
        require(
            _isApprovedOrOwner(_msgSender(), _maNFTId),
            "maNFT: caller is not token owner or approved"
        );

        uint _amount = _lpBalances[_maNFTId];

        require(_amount > 0, "Cannot withdraw 0");
        require(lpTotalSupply() - _amount >= 0, "supply < 0");

        _removeFromPosition(_maNFTId, _amount, _maturityMultiplier(_maNFTId));
        TOKEN.safeTransfer(_ownerOf(_maNFTId), _amount);

        _burn(_maNFTId);
        _positionEntries[_maNFTId] = 0;
        _nftToEpochIds[_maNFTId] = 0;

        emit Withdraw(_msgSender(), _amount);
    }

    ///@notice updates pool total weight
    function sync() external {
        _updateTotalWeight();
    }

    /*
    ///@notice withdraw all TOKEN and harvest rewardToken
    function withdrawAllAndHarvest() external {
        uint[] memory tokenIds = tokensOfOwner(_msgSender());
        uint len = tokenIds.length;
        for ( uint i; i < len; i++) {
            getReward();
            _withdraw( tokenIds[i], _lpBalances[tokenIds[i]]);
        }
    }
    */

    ///@notice User harvest function called from voter ( voter will only call _maNFTIds from the msg.sender )
    function getRewardFromVoter(
        uint _maNFTId
    ) public nonReentrant onlyDistribution updateTotalWeight updateReward(_maNFTId) {
        uint reward = rewards[_maNFTId];
        if (reward > 0) {
            rewards[_maNFTId] = 0;

            rewardToken.safeTransfer(_ownerOf(_maNFTId), reward);

            emit Harvest(_ownerOf(_maNFTId), reward);
        }
    }

    function getRewardFromVoter(
        address _user
    ) public onlyDistribution {

        uint[] memory tokenIds = tokensOfOwner(_user);
        uint len = tokenIds.length;
        for (uint i; i < len; i++) {
            getReward(tokenIds[i]);
        }
    }

    ///@notice User harvest function
    function getReward(
        uint _maNFTId
    ) public nonReentrant updateTotalWeight updateReward(_maNFTId) {
        _getReward(_maNFTId);
    }

    function _getReward(uint _maNFTId) private {
        require(
            _isApprovedOrOwner(_msgSender(), _maNFTId),
            "maNFT: caller is not token owner or approved"
        );

        uint reward = rewards[_maNFTId];
        if (reward > 0) {
            rewards[_maNFTId] = 0;

            rewardToken.safeTransfer(_ownerOf(_maNFTId), reward);

            emit Harvest(_msgSender(), reward);
            //emit Harvest(_ownerOf(_maNFTId), reward);
        }
    }

    ///@notice User harvest all his maNFTs
    function getAllReward() external {
        uint[] memory tokenIds = tokensOfOwner(_msgSender());
        uint len = tokenIds.length;
        for (uint i; i < len; i++) {
            getReward(tokenIds[i]);
        }
    }

    /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    HELPER FUNCTIONS
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */


    function allInfo(uint _tokenId) external view returns(IMaGaugeStruct.MaNftInfo memory _maNftInfo) {

        _maNftInfo.name = name();
        _maNftInfo.symbol = symbol();
        _maNftInfo.pair_address = address(TOKEN);
        //_maNftInfo.vault_address = dyson_maGauge.pair;
        _maNftInfo.vault_address = address(0);
        _maNftInfo.gauge = address(this);

        _maNftInfo.token_id = _tokenId;
        _maNftInfo.owner = ownerOf(_tokenId);
        _maNftInfo.lp_balance = _lpBalances[_tokenId];
        _maNftInfo.emissions_claimable = earned(_tokenId);
        _maNftInfo.weight =  _lpBalances[_tokenId] * _maturityMultiplier(_tokenId);
        _maNftInfo.maturity_time = _positionEntries[_tokenId];
        _maNftInfo.maturity_multiplier = _maturityMultiplier(_tokenId);
    

    }


    function _updateTotalWeight() private {
        // calculate total weight without limit for the pre-limit LP supply
        uint maturityDelta = block.timestamp - _lastTotalWeightUpdateTime;
        _weightIncrement = _weightIncrement + _lpTotalSupplyPreLimit * ((maturityDelta * MATURITY_PRECISION) / maturityIncrement);
        uint totalWeightWithoutLimit = _lpTotalSupplyPreLimit * MATURITY_PRECISION + _weightIncrement;
        // calculate the decrement for this weight for the positions that have reached the limit since last time
        uint totalWeightDecrement = _updateAndGetTotalDecrement();

        // calculate total weight
        _totalWeight = totalWeightWithoutLimit + _lpTotalSupplyPostLimit * MATURITY_PRECISION * 3 - totalWeightDecrement;
        require(_totalWeight >= _lpTotalSupplyPreLimit * MATURITY_PRECISION + _lpTotalSupplyPostLimit * MATURITY_PRECISION * 3, "Total weight is incorrect");
        _lastTotalWeightUpdateTime = block.timestamp;
    }

    ///@dev checks if at least 1 epoch has passed since last check, shifts position LPs, adjusts weight increment and last epoch id
    function _updateAndGetTotalDecrement() private returns (uint totalWeightDecrement) {        
        if (block.timestamp - _lastLpUpdateInEpoch >= LP_EPOCH_DURATION) {
            // calculate how many epochs have passed
            uint epochsShift = (block.timestamp - _lastLpUpdateInEpoch) / LP_EPOCH_DURATION;
            for (uint i; i < epochsShift; i++) {
                // adjust balances of pre and post limits by last LP
                uint lastLP = _epochs[LP_EPOCH_COUNT - 1];
                _lpTotalSupplyPreLimit -= lastLP;
                _lpTotalSupplyPostLimit += lastLP;

                // calculate the multiplier for the last epoch LP based on how many epochs passed
                uint multiplier = MATURITY_PRECISION + ((LP_EPOCH_DURATION * (LP_EPOCH_COUNT + epochsShift - i)) * MATURITY_PRECISION) / maturityIncrement;
                // reduce weight increment by the positions that have passed to the post limit
                uint positionWeightIncrement = lastLP * multiplier - lastLP * MATURITY_PRECISION;

                // the weight of the position is adjusted to the actual recorded increment
                totalWeightDecrement += lastLP * MATURITY_PRECISION + _reduceWeightIncrement(positionWeightIncrement);

                // shift balance of prev epoch to next epoch
                uint currentEpoch = _epochs[0];
                for (uint j; j < LP_EPOCH_COUNT - 1; j++) {
                    uint oldEpoch = _epochs[j + 1];
                    _epochs[j + 1] = currentEpoch;
                    currentEpoch = oldEpoch;
                }
                _epochs[0] = 0;
            }

            // update last epoch based on how many epochs have passed
            _lastLpUpdateInEpoch = _lastLpUpdateInEpoch + LP_EPOCH_DURATION * epochsShift;
            // update index of last epoch based on shifts
            LP_LAST_EPOCH_ID += epochsShift;
        }

    }

    ///@dev calculates maturity multiplier based on the position maturity
    function _maturityMultiplier(uint _maNFTId) public view returns (uint) {
        uint maturity = block.timestamp - _positionEntries[_maNFTId];
        if (maturity >= 2 * maturityIncrement) return MATURITY_PRECISION * 3;
        else return MATURITY_PRECISION +
            (maturity * MATURITY_PRECISION) /
            maturityIncrement;
    }

    ///@dev calculates new entry based on the merged position entries and amounts
    function _getNewEntry(uint firstEntry, uint secondEntry, uint firstAmount, uint secondAmount) private view returns(uint) {
        uint olderEntry;
        uint entryDiff;
        uint addedAmount;
        if (firstEntry < secondEntry) {
            olderEntry = firstEntry;
            entryDiff = secondEntry - firstEntry;
            addedAmount = secondAmount;
        } else {
            olderEntry = secondEntry;
            entryDiff = firstEntry - secondEntry;
            addedAmount = firstAmount;
        }
        uint newEntry = (olderEntry * ENTRY_CALCULATION_PRECISION + entryDiff * addedAmount * ENTRY_CALCULATION_PRECISION / (firstAmount + secondAmount)) / ENTRY_CALCULATION_PRECISION;
        return newEntry;
    }

    ///@dev adds the position weight to total weight, adjusts weight incement, adds postion LP to pool and individual position balance
    function _addToPosition(
        uint id,
        uint amount,
        uint multiplier,
        uint entry
    ) private {
        uint weight = amount * multiplier;

        _totalWeight += weight;

        if (multiplier < MATURITY_PRECISION * 3) {
            _weightIncrement =
                _weightIncrement +
                (weight - amount * MATURITY_PRECISION);
        }

        _increaseLP(id, amount, entry);
        _lpBalances[id] += amount;

        _positionLastWeights[id] = weight;
    }

    ///@dev reduces the total weight by position weight (or remaining total weight), reduces weight increment by position weight, reduces LP balance of pool and position
    function _removeFromPosition(
        uint id,
        uint amount,
        uint multiplier
    ) private {
        uint weight = amount * multiplier;

        // due to the possible error in weight increment precision, it's possible sum(position weight)
        // is slightly > total weight. the following processing is to avoid underflow

        if (weight > _totalWeight) {
            _totalWeight -= _totalWeight;
        } else {
            _totalWeight -= weight;
        }

        if (multiplier < MATURITY_PRECISION * 3) {
            _reduceWeightIncrement(weight - amount * MATURITY_PRECISION);
        }

        _reduceLP(id, amount);
        _lpBalances[id] -= amount;

        _positionLastWeights[id] = 0;
    }

    ///@dev reduces weight due to the possible error in total weight precision, it's possible sum(position weight) is slightly > total weight. the following processing is to avoid underflow
    function _reduceWeightIncrement(uint amount) private returns (uint reduction) {
        if (amount > _weightIncrement) {
            reduction = _weightIncrement;
        } else {
            reduction = amount;
        }
        _weightIncrement -= reduction;
    }

    ///@dev adds the LP to the epoch based on entry and stores the ID of that epoch for future withdrawals
    function _increaseLP(uint id, uint amount, uint entry) private {
        uint currentEpochIndex = (block.timestamp - entry) / LP_EPOCH_DURATION;
        if (currentEpochIndex >= LP_EPOCH_COUNT) {
            _lpTotalSupplyPostLimit += amount;
        } else {
            uint epochId = LP_LAST_EPOCH_ID - currentEpochIndex;
            _epochs[currentEpochIndex] += amount;
            _nftToEpochIds[id] = epochId;
            _lpTotalSupplyPreLimit += amount;
        }
    }

    ///@dev removes the LP from the particular epoch where the position's LP is located
    function _reduceLP(uint id, uint amount) private {
        uint epochId = _nftToEpochIds[id];
        uint currentEpochIndex = LP_LAST_EPOCH_ID - epochId;
        if (currentEpochIndex >= LP_EPOCH_COUNT) {
            _lpTotalSupplyPostLimit -= amount;
        } else {
            _epochs[currentEpochIndex] -= amount;
            _lpTotalSupplyPreLimit -= amount;
        }
    }

    ///@dev creates epochs based on the duration. LP last epoch id is used to identify particular epoch where the position LP is located, that's necessary due to epoch shifts
    function _initializeEpochs(uint epochDuration) private {
        LP_EPOCH_DURATION = epochDuration;
        LP_EPOCH_COUNT = (maturityIncrement * 2) / LP_EPOCH_DURATION;
        LP_LAST_EPOCH_ID = LP_EPOCH_COUNT - 1;
        _lastLpUpdateInEpoch = block.timestamp;
    }


    /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    DISTRIBUTION
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */

    /// @notice Receive rewards from distribution
    function notifyRewardAmount(
        address token,
        uint reward
    ) external nonReentrant isNotEmergency onlyDistribution updateTotalWeight updateReward(0) {
        require(token == address(rewardToken));
        rewardToken.safeTransferFrom(DISTRIBUTION, address(this), reward);

        if (block.timestamp >= periodFinish) {
            rewardRate = reward / DURATION;
        } else {
            uint remaining = periodFinish - block.timestamp;
            uint leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / DURATION;
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = rewardToken.balanceOf(address(this));
        require(rewardRate <= balance / DURATION, "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + DURATION;
        emit RewardAdded(reward);
    }

    function claimFees()
        external
        nonReentrant
        returns (uint claimed0, uint claimed1)
    {
        return _claimFees();
    }

    function _claimFees() internal returns (uint claimed0, uint claimed1) {
        if (!isForPair) {
            return (0, 0);
        }
        address _token = address(TOKEN);
        (claimed0, claimed1) = IPair(_token).claimFees();
        if (claimed0 > 0 || claimed1 > 0) {
            uint _fees0 = fees0 + claimed0;
            uint _fees1 = fees1 + claimed1;
            (address _token0, address _token1) = IPair(_token).tokens();

            if (_fees0 > 0) {
                fees0 = 0;
                IERC20(_token0).safeApprove(internal_bribe, 0);
                IERC20(_token0).safeApprove(internal_bribe, _fees0);
                IBribe(internal_bribe).notifyRewardAmount(_token0, _fees0);
            } else {
                fees0 = _fees0;
            }
            if (_fees1 > 0) {
                fees1 = 0;
                IERC20(_token1).approve(internal_bribe, 0);
                IERC20(_token1).approve(internal_bribe, _fees1);
                IBribe(internal_bribe).notifyRewardAmount(_token1, _fees1);
            } else {
                fees1 = _fees1;
            }
            emit ClaimFees(_msgSender(), claimed0, claimed1);
        }
    }

    function _updateReward(uint _maNFTId) private {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (_maNFTId != 0) {
            rewards[_maNFTId] = earned(_maNFTId);
            _positionLastWeights[_maNFTId] = _lpBalances[_maNFTId] * _maturityMultiplier(_maNFTId);
            idRewardPerTokenPaid[_maNFTId] = rewardPerTokenStored;
        }
    }

    /*///////////////////////////////////////////////////////////////
                             NFT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns current token URI metadata
    /// @param _maNFTId Token ID to fetch URI for.
    function tokenURI(
        uint _maNFTId
    ) public view override returns (string memory) {
        _requireMinted(_maNFTId);

        return
            IMaArtProxy(0xB5Fad4D924166a4AC5390B587D27F94dA3fE2Fe8)._tokenURI(
                _maNFTId
            );
    }

    function tokensOfOwner(address _owner) public view returns (uint[] memory) {
        uint tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            return new uint[](0);
        } else {
            uint[] memory result = new uint[](tokenCount);
            for (uint index; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }

    function isApprovedOrOwner(
        address user,
        uint _maNFTId
    ) external view returns (bool) {
        return _isApprovedOrOwner(user, _maNFTId);
    }

    function update() external returns(bool) {
        return true;
    }

}