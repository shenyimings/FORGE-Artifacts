// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './Nodes.sol';
import './lib/AddressToUintIterableMap.sol';

contract Batch {
    address public owner;
    Nodes public nodes;
    Nodes.SplitStruct private splitStruct;
    uint256[] public auxStack;

    struct Function {
        string id;
        string functionName;
        address user;
        string[] arguments;
        bool hasNext;
    }

    event AddFundsForTokens(string id, address tokenInput, uint256 amount);
    event AddFundsForFTM(string id, uint256 amount);
    event Split(string id, address tokenInput, uint256 amountIn, uint256 amountOutToken1, uint256 amountOutToken2);
    event SwapTokens(string id, address tokenInput, uint256 amountIn, address tokenOutput, uint256 amountOut);
    event Liquidate(string id, IERC20[] tokensInput, uint256[] amountsIn, address tokenOutput, uint256 amountOut);
    event SendToWallet(string id, address tokenOutput, uint256 amountOut);
    event lpDeposited(string id, address lpToken, uint256 amount);
    event ttDeposited(string id, address ttVault, uint256 amount);
    event lpWithdrawed(string id, address lpToken, uint256 amountLp, address tokenDesired, uint256 amountTokenDesired);
    event ttWithdrawed(string id, address ttVault, uint256 amountTt, address tokenDesired, uint256 amountTokenDesired);

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'You must be the owner.');
        _;
    }

    function setNodeContract(Nodes _nodes) public onlyOwner {
        nodes = _nodes;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), 'This function is internal');
        _;
    }

    function batchFunctions(Function[] memory _functions) public onlyOwner {
        for (uint256 i = 0; i < _functions.length; i++) {
            (bool success, ) = address(this).call(abi.encodeWithSignature(_functions[i].functionName, _functions[i]));
            if (!success) revert();
        }
        if (auxStack.length > 0) deleteAuxStack();
    }

    function deleteAuxStack() private {
        for (uint8 i = 1; i <= auxStack.length; i++) {
            auxStack.pop();
        }
    }

    function addFundsForFTM(Function memory args) public onlySelf {
        uint256 amount = StringUtils.safeParseInt(args.arguments[0]);
        if (args.hasNext) {
            auxStack.push(amount);
        }

        emit AddFundsForFTM(args.id, amount);
    }

    function withdrawFromFarm(Function memory args) public onlySelf {
        uint256 amount = StringUtils.safeParseInt(args.arguments[7]);
        if (auxStack.length > 0) {
            amount = auxStack[auxStack.length - 1];
            auxStack.pop();
        }
        uint256 amountTokenDesired = nodes.withdrawFromFarm(args.user, args.arguments, amount);
        emit ttWithdrawed(
            args.id,
            StringUtils.parseAddr(args.arguments[2]),
            amount,
            StringUtils.parseAddr(args.arguments[5]),
            amountTokenDesired
        );
        if (args.hasNext) {
            auxStack.push(amountTokenDesired);
        }
    }

    function withdrawFromLp(Function memory args) public onlySelf {
        uint256 amount = StringUtils.safeParseInt(args.arguments[7]);
        if (auxStack.length > 0) {
            amount = auxStack[auxStack.length - 1];
            auxStack.pop();
        }
        uint256 amountTokenDesired = nodes.withdrawFromLp(args.user, args.arguments, amount);
        emit lpWithdrawed(
            args.id,
            StringUtils.parseAddr(args.arguments[1]),
            amount,
            StringUtils.parseAddr(args.arguments[5]),
            amountTokenDesired
        );
        if (args.hasNext) {
            auxStack.push(amountTokenDesired);
        }
    }

    function depositOnLp(Function memory args) public onlySelf {
        uint256 amount0 = StringUtils.safeParseInt(args.arguments[3]);
        uint256 amount1 = StringUtils.safeParseInt(args.arguments[4]);
        address lpToken = StringUtils.parseAddr(args.arguments[0]);
        if (auxStack.length > 0) {
            amount0 = auxStack[auxStack.length - 2];
            amount1 = auxStack[auxStack.length - 1];
            auxStack.pop();
            auxStack.pop();
        }
        uint256 lpRes = nodes.depositOnLp(
            args.user,
            lpToken,
            StringUtils.parseAddr(args.arguments[1]),
            StringUtils.parseAddr(args.arguments[2]),
            amount0,
            amount1
        );
        emit lpDeposited(args.id, lpToken, lpRes);
        if (args.hasNext) {
            auxStack.push(lpRes);
        }
    }

    function depositOnFarm(Function memory args) public onlySelf {
        (, bytes memory data) = address(nodes).call(
            abi.encodeWithSignature(args.arguments[0], args.user, args.arguments, auxStack)
        );

        uint256[] memory result = abi.decode(data, (uint256[]));
        while (result[0] != 0) {
            auxStack.pop();
            result[0]--;
        }

        emit ttDeposited(args.id, StringUtils.parseAddr(args.arguments[2]), result[1]); // ttVault address and ttAmount
        if (args.hasNext) {
            auxStack.push(result[1]);
        }
    }

    function split(Function memory args) public onlySelf {
        Nodes.SplitStruct memory _splitStruct = splitStruct;
        _splitStruct.user = args.user;
        _splitStruct.token = StringUtils.parseAddr(args.arguments[0]);
        _splitStruct.firstToken = StringUtils.parseAddr(args.arguments[2]);
        _splitStruct.secondToken = StringUtils.parseAddr(args.arguments[3]);
        _splitStruct.percentageFirstToken = StringUtils.safeParseInt(args.arguments[4]);
        _splitStruct.amountOutMinFirst = StringUtils.safeParseInt(args.arguments[5]);
        _splitStruct.amountOutMinSecond = StringUtils.safeParseInt(args.arguments[6]);
        string memory _firstTokenHasNext = args.arguments[7];
        string memory _secondTokenHasNext = args.arguments[8];

        if (auxStack.length > 0) {
            _splitStruct.amount = auxStack[auxStack.length - 1];
            auxStack.pop();
        } else {
            _splitStruct.amount = StringUtils.safeParseInt(args.arguments[1]);
        }

        (uint256 amountOutToken1, uint256 amountOutToken2) = nodes.split(_splitStruct);
        if (StringUtils.equal(_firstTokenHasNext, 'y')) {
            auxStack.push(amountOutToken1);
        }
        if (StringUtils.equal(_secondTokenHasNext, 'y')) {
            auxStack.push(amountOutToken2);
        }
        emit Split(args.id, _splitStruct.token, _splitStruct.amount, amountOutToken1, amountOutToken2);
    }

    function addFundsForTokens(Function memory args) public onlySelf {
        address _token = StringUtils.parseAddr(args.arguments[0]);
        uint256 _amount = StringUtils.safeParseInt(args.arguments[1]);

        uint256 amount = nodes.addFundsForTokens(args.user, IERC20(_token), _amount);
        if (args.hasNext) {
            auxStack.push(amount);
        }

        emit AddFundsForTokens(args.id, _token, amount);
    }

    function swapTokens(Function memory args) public onlySelf {
        address _token = StringUtils.parseAddr(args.arguments[0]);
        uint256 _amount;
        address _newToken = StringUtils.parseAddr(args.arguments[2]);
        uint256 _amountOutMin = StringUtils.safeParseInt(args.arguments[3]);

        if (auxStack.length > 0) {
            _amount = auxStack[auxStack.length - 1];
            auxStack.pop();
        } else {
            _amount = StringUtils.safeParseInt(args.arguments[1]);
        }

        uint256 amountOut = nodes.swapTokens(args.user, IERC20(_token), _amount, _newToken, _amountOutMin);
        if (args.hasNext) {
            auxStack.push(amountOut);
        }

        emit SwapTokens(args.id, _token, _amount, _newToken, amountOut);
    }

    function liquidate(Function memory args) public onlySelf {
        uint256 _tokenArguments = (args.arguments.length - 1) / 2;

        IERC20[] memory _tokens = new IERC20[](_tokenArguments);
        for (uint256 x = 0; x < _tokenArguments; x++) {
            address _token = StringUtils.parseAddr(args.arguments[x]);

            _tokens[x] = IERC20(_token);
        }

        uint256[] memory _amounts = new uint256[](_tokenArguments);
        uint256 y;
        for (uint256 x = _tokenArguments; x < args.arguments.length - 1; x++) {
            uint256 _amount;
            if (auxStack.length > 0) {
                _amount = auxStack[auxStack.length - 1];
                auxStack.pop();
            } else {
                _amount = StringUtils.safeParseInt(args.arguments[x]);
            }

            _amounts[y] = _amount;
            y++;
        }

        address _tokenOutput = StringUtils.parseAddr(args.arguments[args.arguments.length - 1]);

        uint256 amountOut = nodes.liquidate(args.user, _tokens, _amounts, _tokenOutput);

        emit Liquidate(args.id, _tokens, _amounts, _tokenOutput, amountOut);
    }

    function sendToWallet(Function memory args) public onlySelf {
        address _token = StringUtils.parseAddr(args.arguments[0]);
        uint256 _amount;

        if (auxStack.length > 0) {
            _amount = auxStack[auxStack.length - 1];
            auxStack.pop();
        } else {
            _amount = StringUtils.safeParseInt(args.arguments[1]);
        }

        uint256 amount = nodes.sendToWallet(args.user, IERC20(_token), _amount);

        emit SendToWallet(args.id, _token, amount);
    }

    receive() external payable {}
}
