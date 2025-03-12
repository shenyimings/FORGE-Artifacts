pragma solidity 0.5.12;

import "./interface/IHandler.sol";
import "./library/DSAuth.sol";
import "./library/SafeMath.sol";

contract Dispatcher is DSAuth {
    using SafeMath for uint256;

    /**
     * @dev List all handler contract address.
     */
    address[] public handlers;

    address public defaultHandler;

    /**
     * @dev Deposit ratio of each handler contract.
     *      Notice: the sum of all deposit ratio should be 1000000.
     */
    mapping(address => uint256) public proportions;

    uint256 public constant totalProportion = 1000000;

    /**
     * @dev map: handlerAddress -> true/false,
     *      Whether the handler has been added or not.
     */
    mapping(address => bool) public isHandlerActive;

    /**
     * @dev Set original handler contract and its depoist ratio.
     *      Notice: the sum of all deposit ratio should be 1000000.
     * @param _handlers The original support handler contract.
     * @param _proportions The original depoist ratio of support handler.
     */
    constructor(address[] memory _handlers, uint256[] memory _proportions)
        public
    {
        setHandlers(_handlers, _proportions);
    }

    /**
     * @dev Sort handlers in descending order of the liquidity in each market.
     * @param _data The data to sort, which are the handlers here.
     * @param _left The index of data to start sorting.
     * @param _right The index of data to end sorting.
     * @param _token Asset address.
     */
    function sortByLiquidity(
        address[] memory _data,
        int256 _left,
        int256 _right,
        address _token
    ) internal view {
        int256 i = _left;
        int256 j = _right;
        if (i == j) return;

        uint256 _pivot = IHandler(_data[uint256(_left + (_right - _left) / 2)])
            .getLiquidity(_token);
        while (i <= j) {
            while (IHandler(_data[uint256(i)]).getLiquidity(_token) > _pivot)
                i++;
            while (_pivot > IHandler(_data[uint256(j)]).getLiquidity(_token))
                j--;
            if (i <= j) {
                (_data[uint256(i)], _data[uint256(j)]) = (
                    _data[uint256(j)],
                    _data[uint256(i)]
                );
                i++;
                j--;
            }
        }
        if (_left < j) sortByLiquidity(_data, _left, j, _token);
        if (i < _right) sortByLiquidity(_data, i, _right, _token);
    }

    /************************/
    /*** Admin Operations ***/
    /************************/

    /**
     * @dev Replace current handlers with _handlers and corresponding _proportions,
     * @param _handlers The list of new handlers, the 1st one will act as default hanlder.
     * @param _proportions The list of corresponding proportions.
     */
    function setHandlers(
        address[] memory _handlers,
        uint256[] memory _proportions
    ) private {
        require(
            _handlers.length == _proportions.length && _handlers.length > 0,
            "setHandlers: handlers & proportions should not have 0 or different lengths"
        );

        // The 1st will act as the default handler.
        defaultHandler = _handlers[0];

        uint256 _sum = 0;
        for (uint256 i = 0; i < _handlers.length; i++) {
            require(
                _handlers[i] != address(0),
                "setHandlers: handlerAddr contract address invalid"
            );

            _sum = _sum.add(_proportions[i]);

            handlers.push(_handlers[i]);
            proportions[_handlers[i]] = _proportions[i];
            isHandlerActive[_handlers[i]] = true;
        }

        // The sum of proportions should be 1000000.
        require(
            _sum == totalProportion,
            "the sum of proportions must be 1000000"
        );
    }

    /**
     * @dev Update proportions of the handlers.
     * @param _handlers List of the handlers to update.
     * @param _proportions List of the corresponding proportions to update.
     */
    function updateProportions(
        address[] memory _handlers,
        uint256[] memory _proportions
    ) public auth {
        require(
            _handlers.length == _proportions.length &&
                handlers.length == _proportions.length,
            "updateProportions: handlers & proportions must match the current length"
        );

        uint256 _sum = 0;
        for (uint256 i = 0; i < _proportions.length; i++) {
            require(
                isHandlerActive[_handlers[i]],
                "updateProportions: the handler contract address does not exist"
            );
            _sum = _sum.add(_proportions[i]);

            proportions[_handlers[i]] = _proportions[i];
        }

        // The sum of `proportions` should be 1000000.
        require(
            _sum == totalProportion,
            "the sum of proportions must be 1000000"
        );
    }

    /**
     * @dev Add new handler.
     *      Notice: the corresponding proportion of the new handler is 0.
     * @param _handlers List of the new handlers to add.
     */
    function addHandlers(address[] memory _handlers) public auth {
        for (uint256 i = 0; i < _handlers.length; i++) {
            require(
                !isHandlerActive[_handlers[i]],
                "addHandlers: handler address already exists"
            );
            require(
                _handlers[i] != address(0),
                "addHandlers: handler address invalid"
            );

            handlers.push(_handlers[i]);
            proportions[_handlers[i]] = 0;
            isHandlerActive[_handlers[i]] = true;
        }
    }

    /**
     * @dev Reset handlers and corresponding proportions, will delete the old ones.
     * @param _handlers The list of new handlers.
     * @param _proportions the list of corresponding proportions.
     */
    function resetHandlers(
        address[] calldata _handlers,
        uint256[] calldata _proportions
    ) external auth {
        address[] memory _oldHandlers = handlers;
        for (uint256 i = 0; i < _oldHandlers.length; i++) {
            delete proportions[_oldHandlers[i]];
            delete isHandlerActive[_oldHandlers[i]];
        }
        defaultHandler = address(0);
        delete handlers;

        setHandlers(_handlers, _proportions);
    }

    /**
     * @dev Update the default handler.
     * @param _defaultHandler The default handler to update.
     */
    function updateDefaultHandler(address _defaultHandler) public auth {
        require(
            _defaultHandler != address(0),
            "updateDefaultHandler: New defaultHandler should not be zero address"
        );

        address _oldDefaultHandler = defaultHandler;
        require(
            _defaultHandler != _oldDefaultHandler,
            "updateDefaultHandler: Old and new address cannot be the same."
        );

        handlers[0] = _defaultHandler;
        proportions[_defaultHandler] = proportions[_oldDefaultHandler];
        isHandlerActive[_defaultHandler] = true;

        delete proportions[_oldDefaultHandler];
        delete isHandlerActive[_oldDefaultHandler];

        defaultHandler = _defaultHandler;
    }

    /***********************/
    /*** User Operations ***/
    /***********************/

    /**
     * @dev Query the current handlers and the corresponding proportions.
     * @return Return two arrays, the current handlers,
     *         and the corresponding proportions.
     */
    function getHandlers()
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        address[] memory _handlers = handlers;
        uint256[] memory _proportions = new uint256[](_handlers.length);
        for (uint256 i = 0; i < _proportions.length; i++)
            _proportions[i] = proportions[_handlers[i]];

        return (_handlers, _proportions);
    }

    /**
     * @dev According to the proportion, calculate deposit amount for each handler.
     * @param _amount The amount to deposit.
     * @return Return two arrays, the current handlers,
     *         and the corresponding deposit amounts.
     */
    function getDepositStrategy(uint256 _amount)
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        address[] memory _handlers = handlers;

        uint256[] memory _amounts = new uint256[](_handlers.length);

        uint256 _sum = 0;
        uint256 _lastIndex = _amounts.length.sub(1);
        for (uint256 i = 0; ; i++) {
            // Return empty stratege if any handler is paused for abnormal case,
            // resulting further failure with mint and burn
            if (IHandler(_handlers[i]).paused()) {
                delete _handlers;
                delete _amounts;
                break;
            }

            // The last handler gets the remaining amount without check proportion.
            if (i == _lastIndex) {
                _amounts[i] = _amount.sub(_sum);
                break;
            }

            // Calculate deposit amount according to the proportion,
            _amounts[i] =
                _amount.mul(proportions[_handlers[i]]) /
                totalProportion;

            _sum = _sum.add(_amounts[i]);
        }

        return (_handlers, _amounts);
    }

    /**
     * @dev Provide a strategy to withdraw, now sort handlers in descending order of the liquidity.
     * @param _token The token to withdraw.
     * @param _amount The amount to withdraw, including exchange fees between tokens.
     * @return Return two arrays, the handlers,
     *         and the corresponding withdraw amount.
     */
    function getWithdrawStrategy(address _token, uint256 _amount)
        external
        returns (address[] memory, uint256[] memory)
    {
        address[] memory _handlers = handlers;
        // Sort handlers in descending order of the liquidity.
        if (_handlers.length > 2)
            sortByLiquidity(
                _handlers,
                int256(1),
                int256(_handlers.length - 1),
                _token
            );

        uint256[] memory _amounts = new uint256[](_handlers.length);
        uint256 _balance;
        uint256 _lastIndex = _amounts.length.sub(1);
        for (uint256 i = 0; i < _handlers.length; i++) {
            // Return empty stratege if any handler is paused for abnormal case,
            // resulting further failure with mint and burn
            if (IHandler(_handlers[i]).paused()) {
                delete _handlers;
                delete _amounts;
                break;
            }

            // Continue to check whether all handlers are unpaused
            if (_amount == 0) continue;

            if (i == _lastIndex) {
                _amounts[i] = _amount;
                break;
            }

            // The maximum amount can be withdrown from market.
            _balance = IHandler(_handlers[i]).getRealLiquidity(_token);
            _amounts[i] = _balance > _amount ? _amount : _balance;
            _amount = _amount.sub(_amounts[i]);
        }

        return (_handlers, _amounts);
    }
}
