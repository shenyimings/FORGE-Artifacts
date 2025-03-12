// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interfaces/IStorage.sol";
import "./interfaces/ILogicContract.sol";
import "./interfaces/IStrategyContract.sol";
import "./utils/OwnableUpgradeableAdminable.sol";
import "./utils/UpgradeableBase.sol";

contract MultiLogic is UpgradeableBase {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct singleStrategy {
        address logicContract;
        address strategyContract;
    }

    address private storageContract;
    singleStrategy[] private multiStrategy;
    mapping(address => bool) private approvedTokens;
    mapping(address => bool) private approvedTokensLogic;
    mapping(address => mapping(address => uint256)) private dividePercentage;
    mapping(address => mapping(address => uint256)) private tokenAvailableLogic;
    mapping(address => mapping(address => uint256)) private tokenBalanceLogic;
    uint256 public multiStrategyLength;
    string[] public multiStrategyName;
    mapping(string => singleStrategy) private multiStrategyData;
    mapping(address => bool) public isExistLogic;
    address private constant ZERO_ADDRESS = address(0);

    event TakeToken(address token, address logic, uint256 amount);
    event ReturnToken(address token, uint256 amount);
    event ReleaseToken(address token, uint256 amount);
    event AddStrategy(string name, singleStrategy strategies);
    event InitStrategy(string[] strategiesName, singleStrategy[] strategies);
    event SetLogicTokenAvailable(
        uint256 amount,
        address token,
        uint256 deposit_flag
    );

    function __MultiLogicProxy_init() public initializer {
        UpgradeableBase.initialize();
        multiStrategyLength = 0;
    }

    receive() external payable {}

    modifier onlyStorage() {
        require(msg.sender == storageContract, "M1");
        _;
    }

    /**
     * @notice Check if the logic address exist
     */
    modifier onlyExistLogic() {
        require(isExistLogic[msg.sender] == true, "M4");
        _;
    }

    /*** User function ***/

    /**
     * @notice set Storage address
     * @param _storage storage address
     */
    function setStorage(address _storage) external onlyOwner {
        require(storageContract == ZERO_ADDRESS, "M5");
        storageContract = _storage;
    }

    /**
     * @notice Set the dividing percentage
     * @param _token token address
     * @param _percentages percentage array
     */
    function setPercentages(address _token, uint256[] memory _percentages)
        public
        onlyOwner
    {
        uint256 _count = multiStrategyLength;
        uint256 sumTotal = 0;
        uint256 index;
        uint256[] memory releaseAmounts = new uint256[](_count);
        uint256 sumReleaseAmount = 0;

        require(_percentages.length == _count, "M2");

        mapping(address => uint256)
            storage _tokenAvailable = tokenAvailableLogic[_token];
        mapping(address => uint256) storage _tokenBalance = tokenBalanceLogic[
            _token
        ];

        // Check sum of percentage
        {
            uint256 sumPercentage = 0;
            for (index = 0; index < _count; ) {
                sumPercentage += _percentages[index];
                unchecked {
                    ++index;
                }
            }
            require(sumPercentage == 10000, "M3");
        }

        // Get sum of total
        for (index = 0; index < _count; ) {
            singleStrategy memory sStrategy = multiStrategyData[
                multiStrategyName[index]
            ];

            // Calculate sum
            sumTotal +=
                _tokenAvailable[sStrategy.logicContract] +
                _tokenBalance[sStrategy.logicContract];

            // Set percentage
            dividePercentage[_token][sStrategy.logicContract] = _percentages[
                index
            ];

            unchecked {
                ++index;
            }
        }

        // Set avaliable, balance for each strategy
        if (sumTotal > 0) {
            uint256 sum = 0;
            for (index = 0; index < _count; ) {
                singleStrategy memory sStrategy = multiStrategyData[
                    multiStrategyName[index]
                ];

                // calculate total for each strategy
                uint256 newTotal;
                if (index == _count - 1) {
                    newTotal = sumTotal - sum;
                } else {
                    newTotal = (sumTotal * _percentages[index]) / 10000;
                    sum += newTotal;
                }

                if (newTotal < _tokenBalance[sStrategy.logicContract]) {
                    // If newTotal < balance, balance = newTotal, available = 0
                    releaseAmounts[index] =
                        _tokenBalance[sStrategy.logicContract] -
                        newTotal;
                    _tokenBalance[sStrategy.logicContract] = newTotal;
                    _tokenAvailable[sStrategy.logicContract] = 0;

                    sumReleaseAmount += releaseAmounts[index];
                } else {
                    // If newTotal > balance, available = newTotal - balance;
                    _tokenAvailable[sStrategy.logicContract] =
                        newTotal -
                        _tokenBalance[sStrategy.logicContract];
                }

                unchecked {
                    ++index;
                }
            }
        }

        // Release token for each strategy and send token to storage
        if (sumReleaseAmount > 0) {
            // ReleaseToken for each strategy and take token from Logic to MultiLogic
            for (index = 0; index < _count; ) {
                if (releaseAmounts[index] > 0) {
                    singleStrategy memory sStrategy = multiStrategyData[
                        multiStrategyName[index]
                    ];

                    IStrategy(sStrategy.strategyContract).releaseToken(
                        releaseAmounts[index],
                        _token
                    );

                    if (_token != ZERO_ADDRESS) {
                        IERC20Upgradeable(_token).safeTransferFrom(
                            sStrategy.logicContract,
                            address(this),
                            releaseAmounts[index]
                        );
                    }
                }

                unchecked {
                    ++index;
                }
            }

            // Send tokens to storage
            if (_token != ZERO_ADDRESS) {
                if (!approvedTokens[_token]) {
                    //if token not approved for storage
                    IERC20Upgradeable(_token).approve(
                        storageContract,
                        type(uint256).max
                    );
                    approvedTokens[_token] = true;
                }
            } else {
                _send(payable(storageContract), sumReleaseAmount);
            }

            IStorage(storageContract).returnToken(sumReleaseAmount, _token);
        }
    }

    /**
     * @notice Init the Logic address into MultiLogicProxy
     * @param _strategyName strategy name array
     * @param _multiStrategy strategy array
     */
    function initStrategies(
        string[] calldata _strategyName,
        singleStrategy[] calldata _multiStrategy
    ) external onlyOwner {
        uint256 count = _multiStrategy.length;
        uint256 nameCount = _strategyName.length;
        require(count == nameCount, "M2");
        require(count != 0, "M11");

        // Remove exist strategies
        for (uint256 i = 0; i < multiStrategyLength; ) {
            isExistLogic[
                multiStrategyData[multiStrategyName[i]].logicContract
            ] = false;

            unchecked {
                ++i;
            }
        }
        delete multiStrategyName;

        // Add new strategies

        for (uint256 i = 0; i < count; ) {
            require(_multiStrategy[i].logicContract != ZERO_ADDRESS, "M11");
            require(_multiStrategy[i].strategyContract != ZERO_ADDRESS, "M11");

            multiStrategyName.push(_strategyName[i]);
            multiStrategyData[_strategyName[i]] = _multiStrategy[i];
            isExistLogic[_multiStrategy[i].logicContract] = true;
            unchecked {
                ++i;
            }
        }
        multiStrategyLength = count;

        emit InitStrategy(_strategyName, _multiStrategy);
    }

    /**
     * @notice Set the Logic address into MultiLogicProxy
     * @param _strategyName strategy name
     * @param _multiStrategy strategy
     * @param _overwrite overwrite flag
     */
    function addStrategy(
        string memory _strategyName,
        singleStrategy memory _multiStrategy,
        bool _overwrite
    ) external onlyOwner {
        require(_multiStrategy.logicContract != ZERO_ADDRESS, "M11");
        require(_multiStrategy.strategyContract != ZERO_ADDRESS, "M11");

        bool exist = false;
        for (uint256 i = 0; i < multiStrategyLength; ) {
            if (
                keccak256(abi.encodePacked((multiStrategyName[i]))) ==
                keccak256(abi.encodePacked((_strategyName)))
            ) {
                require(_overwrite, "M9");
                exist = true;
                break;
            }
            unchecked {
                ++i;
            }
        }

        if (exist) {
            isExistLogic[
                multiStrategyData[_strategyName].logicContract
            ] = false;
        } else {
            multiStrategyName.push(_strategyName);
            multiStrategyLength++;
        }

        multiStrategyData[_strategyName] = _multiStrategy;
        isExistLogic[_multiStrategy.logicContract] = true;

        emit AddStrategy(_strategyName, _multiStrategy);
    }

    /**
     * @notice Set percentage of strategy to be 0
     * destroyAll for that strategy
     * rebalance existing strategies
     * @param _strategyName strategy name
     */
    function deactivateStrategy(string memory _strategyName)
        external
        onlyOwner
    {
        uint256 _multiStrategyLength = multiStrategyLength;

        // Check if exists and get index of strategy
        bool exist = false;
        uint256 indexOfStrategy = 0;
        for (uint256 i = 0; i < multiStrategyLength; ) {
            if (
                keccak256(abi.encodePacked((multiStrategyName[i]))) ==
                keccak256(abi.encodePacked((_strategyName)))
            ) {
                exist = true;
                indexOfStrategy = i;
                break;
            }
            unchecked {
                ++i;
            }
        }

        if (!exist) {
            return;
        }

        // Update Percentages of strategies
        address[] memory usedTokens = IStorage(storageContract).getUsedTokens();
        for (uint256 i = 0; i < usedTokens.length; ) {
            address _token = usedTokens[i];
            uint256[] memory newPercentages = new uint256[](
                _multiStrategyLength
            );

            singleStrategy memory sStrategy = multiStrategyData[
                multiStrategyName[indexOfStrategy]
            ];

            // Get percentage of strategy
            uint256 percentageOfStrategy = dividePercentage[_token][
                sStrategy.logicContract
            ];

            // if the percentage is 100%, destroyAll and update percentage, available, balance = 0
            if (percentageOfStrategy == 10000) {
                uint256 tokenBalance = tokenBalanceLogic[_token][
                    sStrategy.logicContract
                ];
                IStrategy(sStrategy.strategyContract).releaseToken(
                    tokenBalance,
                    _token
                );

                if (_token != ZERO_ADDRESS) {
                    IERC20Upgradeable(_token).safeTransferFrom(
                        sStrategy.logicContract,
                        address(this),
                        tokenBalance
                    );
                }

                IStorage(storageContract).returnToken(tokenBalance, _token);
                dividePercentage[_token][sStrategy.logicContract] = 0;
                tokenAvailableLogic[_token][sStrategy.logicContract] = 0;
                tokenBalanceLogic[_token][sStrategy.logicContract] = 0;
            } else {
                // If it is already deactivated, skip this token
                if (percentageOfStrategy > 0) {
                    // Calculate new percentages of strategy
                    uint256 sumPercentages = 0;
                    for (uint256 j = 0; j < _multiStrategyLength; ) {
                        if (j == indexOfStrategy) {
                            newPercentages[j] = 0;
                        } else {
                            newPercentages[j] =
                                (dividePercentage[_token][
                                    multiStrategyData[multiStrategyName[j]]
                                        .logicContract
                                ] * 10000) /
                                (10000 - percentageOfStrategy);

                            sumPercentages += newPercentages[j];
                        }
                        unchecked {
                            ++j;
                        }
                    }

                    // Fix odd
                    if (sumPercentages < 10000) {
                        if (indexOfStrategy == _multiStrategyLength - 1) {
                            newPercentages[_multiStrategyLength - 2] +=
                                10000 -
                                sumPercentages;
                        } else {
                            newPercentages[_multiStrategyLength - 1] +=
                                10000 -
                                sumPercentages;
                        }
                    }

                    // Update percentages
                    setPercentages(_token, newPercentages);
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /*** Storage function ***/

    /**
     * @notice Set Token balance for each logic
     * @param _amount deposit amount
     * @param _token deposit token
     * @param _deposit_withdraw flag for deposit or withdraw 1 : increase, 0: decrease, 2: set
     */
    function setLogicTokenAvailable(
        uint256 _amount,
        address _token,
        uint256 _deposit_withdraw
    ) external {
        require(msg.sender == owner() || msg.sender == storageContract, "M1");

        uint256 _count = multiStrategyLength;
        uint256 _amountDelta = 0;
        uint256 sum = 0;

        for (uint256 i = 0; i < _count; i++) {
            address logicAddress = multiStrategyData[multiStrategyName[i]]
                .logicContract;

            uint256 newAvailableAmount = ((_amount *
                dividePercentage[_token][logicAddress]) / 10000);

            if (i == _count - 1) {
                // if the final strategy, newAvailableAmount = shifted delta from previous strategy
                newAvailableAmount = _amount - sum;
            } else {
                // newAvailableAmount += shifted delta from previous strategy
                newAvailableAmount += _amountDelta;
                sum += newAvailableAmount;
            }

            if (_deposit_withdraw == 1) {
                // increase
                tokenAvailableLogic[_token][logicAddress] += newAvailableAmount;
            } else if (_deposit_withdraw == 0) {
                // decrease
                if (
                    tokenAvailableLogic[_token][logicAddress] >=
                    newAvailableAmount
                ) {
                    tokenAvailableLogic[_token][
                        logicAddress
                    ] -= newAvailableAmount;
                    _amountDelta = 0;
                } else {
                    _amountDelta =
                        newAvailableAmount -
                        tokenAvailableLogic[_token][logicAddress];
                    tokenAvailableLogic[_token][logicAddress] = 0;
                    if (i < _count - 1) sum -= _amountDelta;
                }
            } else {
                // set
                tokenAvailableLogic[_token][logicAddress] = newAvailableAmount;
            }
        }

        // if we have delta, then decrease available for previous strategy
        if (_deposit_withdraw == 0 && _amountDelta > 0) {
            for (uint256 i = 0; i < _count; ) {
                singleStrategy memory sStrategy = multiStrategyData[
                    multiStrategyName[i]
                ];

                uint256 available = tokenAvailableLogic[_token][
                    sStrategy.logicContract
                ];
                if (available > 0) {
                    if (available >= _amountDelta) {
                        tokenAvailableLogic[_token][
                            sStrategy.logicContract
                        ] -= _amountDelta;
                        _amountDelta = 0;

                        break;
                    } else {
                        tokenAvailableLogic[_token][
                            sStrategy.logicContract
                        ] = 0;
                        _amountDelta -= available;
                    }
                }

                unchecked {
                    ++i;
                }
            }
        }

        emit SetLogicTokenAvailable(_amount, _token, _deposit_withdraw);
    }

    /**
     * @notice Transfer amount of token from Logic to Storage Contract.
     * @param _amount Amount of token
     * @param _token Address of token
     */
    function releaseToken(uint256 _amount, address _token)
        external
        onlyStorage
    {
        uint256 _count = multiStrategyLength;
        uint256 _amountDelta = 0;
        uint256[] memory releaseAmounts = new uint256[](_count);
        uint256 _amountReleaseSum = 0;

        for (uint256 i = 0; i < _count; ) {
            singleStrategy memory sStrategy = multiStrategyData[
                multiStrategyName[i]
            ];

            uint256 releaseAmount;
            if (i == _count - 1) {
                // For the final strategy, we calculate remains
                releaseAmount = _amount - _amountReleaseSum;
            } else {
                // releaseAmount = percentage + shifted delta from previous strategy
                releaseAmount =
                    (_amount *
                        dividePercentage[_token][sStrategy.logicContract]) /
                    10000 +
                    _amountDelta;
            }

            // If balance < releaseAmount, release balance and shift delta to next strategy
            uint256 balance = tokenBalanceLogic[_token][
                sStrategy.logicContract
            ];
            if (balance < releaseAmount) {
                _amountDelta = releaseAmount - balance;
                releaseAmount = balance;
            } else {
                _amountDelta = 0;
            }

            // Decrease balance
            if (releaseAmount > 0) {
                tokenBalanceLogic[_token][
                    sStrategy.logicContract
                ] -= releaseAmount;

                releaseAmounts[i] = releaseAmount;

                if (_amount == 0) {
                    break;
                }
            }

            _amountReleaseSum += releaseAmount;
            // We don't update tokenAvaliable, because it is updated in Storage

            unchecked {
                ++i;
            }
        }

        // if we have delta, then increase releaseAmount for available strategies
        if (_amountDelta > 0) {
            for (uint256 i = 0; i < _count; ) {
                singleStrategy memory sStrategy = multiStrategyData[
                    multiStrategyName[i]
                ];

                uint256 balance = tokenBalanceLogic[_token][
                    sStrategy.logicContract
                ];
                if (balance > 0) {
                    if (balance >= _amountDelta) {
                        releaseAmounts[i] += _amountDelta;
                        tokenBalanceLogic[_token][
                            sStrategy.logicContract
                        ] -= _amountDelta;
                        _amountDelta = 0;

                        break;
                    } else {
                        releaseAmounts[i] += balance;
                        tokenBalanceLogic[_token][sStrategy.logicContract] = 0;
                        _amountDelta -= balance;
                    }
                }

                unchecked {
                    ++i;
                }
            }
        }

        require(_amountDelta == 0, "M7");

        // Interaction
        for (uint256 i = 0; i < _count; ) {
            if (releaseAmounts[i] > 0) {
                singleStrategy memory sStrategy = multiStrategyData[
                    multiStrategyName[i]
                ];

                IStrategy(sStrategy.strategyContract).releaseToken(
                    releaseAmounts[i],
                    _token
                );

                if (_token != ZERO_ADDRESS) {
                    IERC20Upgradeable(_token).safeTransferFrom(
                        sStrategy.logicContract,
                        address(this),
                        releaseAmounts[i]
                    );
                }
            }

            unchecked {
                ++i;
            }
        }

        if (_token == ZERO_ADDRESS) {
            require(address(this).balance >= _amount, "M7");
            _send(payable(storageContract), _amount);
        } else {
            if (!approvedTokens[_token]) {
                //if token not approved for storage
                IERC20Upgradeable(_token).approve(
                    storageContract,
                    type(uint256).max
                );
                approvedTokens[_token] = true;
            }
        }

        emit ReleaseToken(_token, _amount);
    }

    /*** Logic function ***/

    /**
     * @notice Transfer amount of token from Storage to Logic Contract.
     * @param _amount Amount of token
     * @param _token Address of token
     */
    function takeToken(uint256 _amount, address _token)
        external
        onlyExistLogic
    {
        uint256 tokenAvailable = getTokenAvailable(_token, msg.sender);
        require(_amount <= tokenAvailable, "M6");

        tokenAvailableLogic[_token][msg.sender] -= _amount;
        tokenBalanceLogic[_token][msg.sender] += _amount;

        // Interaction
        IStorage(storageContract).takeToken(_amount, _token);

        if (_token == ZERO_ADDRESS) {
            require(address(this).balance >= _amount, "M7");
            _send(payable(msg.sender), _amount);
        } else {
            IERC20Upgradeable(_token).safeTransfer(msg.sender, _amount);
        }

        emit TakeToken(_token, msg.sender, _amount);
    }

    /**
     * @notice Transfer amount of token from Logic to Storage Contract.
     * @param _amount Amount of token
     * @param _token Address of token
     */
    function returnToken(uint256 _amount, address _token)
        external
        onlyExistLogic
    {
        require(_amount <= tokenBalanceLogic[_token][msg.sender], "M6");

        tokenAvailableLogic[_token][msg.sender] += _amount;
        tokenBalanceLogic[_token][msg.sender] -= _amount;

        // Interaction
        if (_token == ZERO_ADDRESS) {
            require(address(this).balance >= _amount, "M7");
            _send(payable(storageContract), _amount);
        } else {
            if (!approvedTokens[_token]) {
                //if token not approved for storage
                IERC20Upgradeable(_token).approve(
                    storageContract,
                    type(uint256).max
                );
                approvedTokens[_token] = true;
            }

            IERC20Upgradeable(_token).safeTransferFrom(
                msg.sender,
                address(this),
                _amount
            );
        }

        IStorage(storageContract).returnToken(_amount, _token);

        emit ReturnToken(_token, _amount);
    }

    /**
     * @notice Take amount BLID from Logic contract  and distributes earned BLID
     * @param _amount Amount of distributes earned BLID
     * @param _blidToken blidToken address
     */
    function addEarn(uint256 _amount, address _blidToken)
        external
        onlyExistLogic
    {
        if (!approvedTokens[_blidToken]) {
            //if token not approved for storage
            IERC20Upgradeable(_blidToken).approve(
                storageContract,
                type(uint256).max
            );
            approvedTokens[_blidToken] = true;
        }

        IERC20Upgradeable(_blidToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        IStorage(storageContract).addEarn(_amount);
    }

    /*** Public view function ***/

    /**
     * @notice Return deposited usd
     */
    function getTotalDeposit() external view returns (uint256) {
        return IStorage(storageContract).getTotalDeposit();
    }

    /**
     * @notice Returns the available amount of token for the logic
     * @param _token deposit token
     * @param _logicAddress logic Address
     */
    function getTokenAvailable(address _token, address _logicAddress)
        public
        view
        returns (uint256)
    {
        return tokenAvailableLogic[_token][_logicAddress];
    }

    /**
     * @notice Returns the taken amount of token for the logic
     * @param _token deposit token
     * @param _logicAddress logic Address
     */
    function getTokenTaken(address _token, address _logicAddress)
        public
        view
        returns (uint256)
    {
        return tokenBalanceLogic[_token][_logicAddress];
    }

    /**
     * @notice Return percentage value
     * @param _token deposit token
     */
    function getPercentage(address _token)
        external
        view
        returns (uint256[] memory)
    {
        uint256 _count = multiStrategyLength;
        uint256[] memory ret = new uint256[](_count);
        for (uint256 i = 0; i < _count; i++) {
            ret[i] = dividePercentage[_token][
                multiStrategyData[multiStrategyName[i]].logicContract
            ];
        }
        return ret;
    }

    /**
     * @notice Set the Logic address into MultiLogicProxy
     * @param _name strategy name
     */
    function strategyInfo(string memory _name)
        external
        view
        returns (address, address)
    {
        bool exist = false;
        for (uint256 i = 0; i < multiStrategyLength; ) {
            if (
                keccak256(abi.encodePacked((multiStrategyName[i]))) ==
                keccak256(abi.encodePacked((_name)))
            ) {
                exist = true;
                break;
            }
            unchecked {
                ++i;
            }
        }
        require(exist == true, "M10");
        return (
            multiStrategyData[_name].logicContract,
            multiStrategyData[_name].strategyContract
        );
    }

    /**
     * @notice Get used tokens in storage
     */
    function getUsedTokensStorage() external view returns (address[] memory) {
        return IStorage(storageContract).getUsedTokens();
    }

    /*** Private function ***/

    /**
     * @notice Send ETH to address
     * @param _to target address to receive ETH
     * @param amount ETH amount (wei) to be sent
     */
    function _send(address payable _to, uint256 amount) private {
        (bool sent, ) = _to.call{value: amount}("");
        require(sent, "M8");
    }
}
