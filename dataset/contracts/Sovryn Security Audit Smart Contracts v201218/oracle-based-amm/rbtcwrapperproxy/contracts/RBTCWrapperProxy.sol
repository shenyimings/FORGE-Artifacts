pragma solidity 0.5.16;

import "./openzeppelin/Address.sol";
import "./openzeppelin/SafeMath.sol";
import "./interfaces/ILiquidityPoolV1Converter.sol";
import "./interfaces/ILiquidityPoolV2Converter.sol";
import "./interfaces/ISmartToken.sol";
import "./interfaces/IERC20Token.sol";
import "./interfaces/IWrbtcERC20.sol";
import "./interfaces/ISovrynSwapNetwork.sol";
import "./interfaces/ISovrynSwapFormula.sol";
import "./interfaces/IContractRegistry.sol";
import "./ContractRegistryClient.sol";
import "./mockups/LiquidityMining.sol";
import "./interfaces/ILoanToken.sol";

contract RBTCWrapperProxy is ContractRegistryClient {
    
    using Address for address;
    using SafeMath for uint256;

    address public wrbtcTokenAddress;
    address public sovrynSwapNetworkAddress;
    LiquidityMining public liquidityMiningContract;
    
    /**
     * @dev triggered after liquidity is added
     *
     * @param  _provider           liquidity provider
     * @param  _reserveAmount      provided reserve token amount
     * @param  _poolTokenAmount    minted pool token amount
     */
    event LiquidityAdded(
        address indexed _provider,
        uint256 _reserveAmount,
        uint256 _poolTokenAmount
    );

    /**
     * @dev triggered after liquidity is added to LiquidityPoolConverter V1
     *
     * @param  _provider           liquidity provider
     * @param  _reserveTokens      provided reserve token
     * @param  _reserveAmounts      provided reserve token amount
     * @param  _poolTokenAmount    minted pool token amount
     */
    event LiquidityAddedToV1(
        address indexed _provider,
        IERC20Token[] _reserveTokens, 
        uint256[] _reserveAmounts, 
        uint256 _poolTokenAmount
    );

    /**
     * @dev triggered after liquidity is removed
     *
     * @param  _provider           liquidity provider
     * @param  _reserveAmount      added reserve token amount
     * @param  _poolTokenAmount    burned pool token amount
     */
    event LiquidityRemoved(
        address indexed _provider,
        uint256 _reserveAmount,
        uint256 _poolTokenAmount
    );

    /**
     * @dev triggered after liquidity is removed from LiquidityPoolConverter V1
     *
     * @param  _provider          liquidity provider
     * @param  _reserveTokens     added reserve tokens
     * @param  _reserveAmounts    added reserve token amounts
     */
    event LiquidityRemovedFromV1(
        address indexed _provider,
        IERC20Token[] _reserveTokens,
        uint256[] _reserveAmounts,
        uint256 _poolTokenAmount
    );

    /**
     * @dev triggered after liquidity is removed
     *
     * @param _beneficiary          account that will receive the conversion result or 0x0 to send the result to the sender account
     * @param _sourceTokenAmount    amount to convert from, in the source token
     * @param _targetTokenAmount    amount of tokens received from the conversion, in the target token
     * @param _path                 conversion path between two tokens in the network
     */
    event TokenConverted(
        address indexed _beneficiary,
        uint256 indexed _sourceTokenAmount,
        uint256 indexed _targetTokenAmount,
        IERC20Token[] _path
    );

    /**
     * @dev triggered after loan tokens are minted
     * @param user the user address
     * @param poolTokenAmount the minted amount of pool tokens
     * @param assetAmount the deposited amount of underlying asset tokens 
     */
    event LoanTokensMinted(
        address indexed user,
        uint256 poolTokenAmount,
        uint256 assetAmount
    );

    /**
     * @dev triggered after loan tokens are minted
     * @param user the user address
     * @param poolTokenAmount the burnt amount of pool tokens
     * @param assetAmount the withdrawn amount of underlying asset tokens 
     */
    event LoanTokensBurnt(
        address indexed user,
        uint256 poolTokenAmount,
        uint256 assetAmount
    );

    /**
     * @dev To check if ddress is contract address 
     */
    modifier checkAddress(address address_) {
        require(address_.isContract(), "The address is not a contract");
        _;
    }
    
    constructor(
        address _wrbtcTokenAddress, 
        address _sovrynSwapNetworkAddress,
        IContractRegistry _registry,
        address liquidityMiningAddress
    ) 
        public
        ContractRegistryClient(_registry)
        checkAddress(_wrbtcTokenAddress) 
        checkAddress(_sovrynSwapNetworkAddress) 
    {
        wrbtcTokenAddress = _wrbtcTokenAddress;
        sovrynSwapNetworkAddress = _sovrynSwapNetworkAddress;
        liquidityMiningContract = LiquidityMining(liquidityMiningAddress);
    }

    function() external payable {
        require(wrbtcTokenAddress == msg.sender, "Only can receive rBTC from WRBTC contract");
    }

    /**
     * @dev  
     * The process:
     * 1.Accepts RBTC
     * 2.Sends RBTC to WRBTC contract in order to wrap RBTC to WRBTC
     * 3.Calls 'addLiquidity' on LiquidityPoolConverter contract
     * 4.Transfers pool tokens to user
     * 
     * @param _liquidityPoolConverterAddress    address of LiquidityPoolConverter contract
     * @param _reserveAddress                   address of the reserve to add to the pool
     * @param _amount                           amount of liquidity to add
     * @param _minReturn                        minimum return-amount of reserve tokens
     *
     * @return amount of pool tokens minted
     */
    function addLiquidityToV2(
        address _liquidityPoolConverterAddress, 
        address _reserveAddress,
        uint256 _amount, 
        uint256 _minReturn
    )  
        public
        payable
        checkAddress(_liquidityPoolConverterAddress)
        returns(uint256) 
    {
        ILiquidityPoolV2Converter _liquidityPoolConverter = ILiquidityPoolV2Converter(_liquidityPoolConverterAddress);
        IERC20Token reserveToken = IERC20Token(_reserveAddress);
        ISmartToken _poolToken = _liquidityPoolConverter.poolToken(reserveToken);

        //wrap rbtc if required
        if(_reserveAddress == wrbtcTokenAddress){
            require(_amount == msg.value, "The provided amount should be identical to msg.value");
            IWrbtcERC20(wrbtcTokenAddress).deposit.value(_amount)();
        }
        else{
            reserveToken.transferFrom(msg.sender, address(this), _amount);
        }

        require(reserveToken.approve(_liquidityPoolConverterAddress, _amount), "token approval failed");

        uint256 poolTokenAmount = _liquidityPoolConverter.addLiquidity(reserveToken, _amount, _minReturn);
        
        //deposit the pool tokens in the liquidity mining contract on the sender's behalf
        _poolToken.approve(address(liquidityMiningContract), poolTokenAmount);
        liquidityMiningContract.deposit(address(_poolToken), poolTokenAmount, msg.sender);

        emit LiquidityAdded(msg.sender, _amount, poolTokenAmount);
        
        return poolTokenAmount;
    }

    /**
     * @dev  
     * The process:
     * 1.Accepts RBTC
     * 2.Sends RBTC to WRBTC contract in order to wrap RBTC to WRBTC
     * 3.Accepts reserve token and approve LiquidityPoolConverter to transfer
     * 4.Calls 'addLiquidity' on LiquidityPoolConverter contract
     * 5.Transfers pool tokens to user
     * 
     * @param _liquidityPoolConverterAddress    address of LiquidityPoolConverter contract
     * @param _reserveTokens                    address of each reserve token. The first element should be the address of WRBTC
     * @param _reserveAmounts                   amount of each reserve token. The first element should be the amount of RBTC
     * @param _minReturn                        minimum return-amount of reserve tokens
     *
     * @return amount of pool tokens minted
     */
    function addLiquidityToV1(
        address _liquidityPoolConverterAddress,
        IERC20Token[] memory _reserveTokens, 
        uint256[] memory _reserveAmounts, 
        uint256 _minReturn
    )  
        public
        payable
        checkAddress(_liquidityPoolConverterAddress)
        returns(uint256) 
    {
        require(address(_reserveTokens[0]) == wrbtcTokenAddress, "The first reserve token must be WRBTC");
        require(_reserveAmounts[0] == msg.value, "The provided amount of RBTC should be identical to msg.value");

        bool success;
        uint256 amount;
        ILiquidityPoolV1Converter _liquidityPoolConverter = ILiquidityPoolV1Converter(_liquidityPoolConverterAddress);
        ISmartToken _poolToken = ISmartToken(address(_liquidityPoolConverter.token()));
        uint32 reserveRatio_ = _liquidityPoolConverter.reserveRatio();
        uint256 totalSupplyBefore = _poolToken.totalSupply();
        uint256[] memory rsvBalances = new uint256[](_reserveTokens.length);

        IWrbtcERC20(wrbtcTokenAddress).deposit.value(_reserveAmounts[0])();
        success = IWrbtcERC20(wrbtcTokenAddress).approve(_liquidityPoolConverterAddress, _reserveAmounts[0]);
        require(success, "Failed to approve converter to transfer WRBTC");
        
        for (uint256 i = 1; i < _reserveTokens.length; i++) {
            success = IERC20Token(_reserveTokens[i]).transferFrom(msg.sender, address(this), _reserveAmounts[i]);
            require(success, "Failed to transfer reserve token from user");
            success = IERC20Token(_reserveTokens[i]).approve(_liquidityPoolConverterAddress, _reserveAmounts[i]);
            require(success, "Failed to approve converter to transfer reserve token");

            (rsvBalances[i], , , , ) = _liquidityPoolConverter.reserves(address(_reserveTokens[i]));
        }

        (rsvBalances[0], , , , ) = _liquidityPoolConverter.reserves(wrbtcTokenAddress);

        uint256 poolTokenAmountBefore = _poolToken.balanceOf(address(this));
        _liquidityPoolConverter.addLiquidity(_reserveTokens, _reserveAmounts, _minReturn);
        uint256 poolTokenAmount = _poolToken.balanceOf(address(this)).sub(poolTokenAmountBefore);
        
        //deposit the pool tokens in the liquidity mining contract on the sender's behalf
        _poolToken.approve(address(liquidityMiningContract), poolTokenAmount);
        liquidityMiningContract.deposit(address(_poolToken), poolTokenAmount, msg.sender);

        for (uint256 i = 1; i < _reserveTokens.length; i++) {
            amount = _reserveAmounts[i].sub(ISovrynSwapFormula(addressOf(SOVRYNSWAP_FORMULA)).fundCost(totalSupplyBefore, rsvBalances[i], reserveRatio_, poolTokenAmount));
            if (amount > 0) {
                success = _reserveTokens[i].transfer(msg.sender, amount);
                require(success, "Failed to transfer extra reserve token back to user");
            }
        }
        
        amount = _reserveAmounts[0].sub(ISovrynSwapFormula(addressOf(SOVRYNSWAP_FORMULA)).fundCost(totalSupplyBefore, rsvBalances[0], reserveRatio_, poolTokenAmount));
        if (amount > 0) {
            IWrbtcERC20(wrbtcTokenAddress).withdraw(amount);
            (success,) = msg.sender.call.value(amount)("");
            require(success, "Failed to send extra RBTC back to user");
        }

        emit LiquidityAddedToV1(msg.sender, _reserveTokens, _reserveAmounts, poolTokenAmount);

        return poolTokenAmount;
    }
    
    /**
     * @notice 
     * Before calling this function to remove liquidity, users need approve this contract to be able to spend or transfer their pool tokens
     *
     * @dev  
     * The process:     
     * 1.Transfers pool tokens to this contract
     * 2.Calls 'removeLiquidity' on LiquidityPoolConverter contract
     * 3.Calls 'withdraw' on WRBTC contract in order to unwrap WRBTC to RBTC
     * 4.Sneds RBTC to user
     * 
     * @param _liquidityPoolConverterAddress    address of LiquidityPoolConverter contract
     * @param _reserveAddress                   address of the reserve to add to the pool
     * @param _amount                           amount of pool tokens to burn
     * @param _minReturn                        minimum return-amount of reserve tokens
     * 
     * @return amount of liquidity removed also WRBTC unwrapped to RBTC
     */
    function removeLiquidityFromV2(
        address _liquidityPoolConverterAddress, 
        address _reserveAddress,
        uint256 _amount, 
        uint256 _minReturn
    )   
        public 
        checkAddress(_liquidityPoolConverterAddress)
        returns(uint256) 
    {
        ILiquidityPoolV2Converter _liquidityPoolConverter = ILiquidityPoolV2Converter(_liquidityPoolConverterAddress);
        IERC20Token reserveToken = IERC20Token(_reserveAddress);
        ISmartToken _poolToken = _liquidityPoolConverter.poolToken(IERC20Token(_reserveAddress));

        //withdraw always transfers the pool tokens to the caller and the reward tokens to the passed address
        liquidityMiningContract.withdraw(address(_poolToken), _amount, msg.sender);

        uint256 reserveAmount = _liquidityPoolConverter.removeLiquidity(_poolToken, _amount, _minReturn);
        
        if(_reserveAddress == wrbtcTokenAddress){
            IWrbtcERC20(wrbtcTokenAddress).withdraw(reserveAmount);
            (bool success, ) = msg.sender.call.value(reserveAmount)("");
            require(success, "Failed to send RBTC to the user");
        }
        else{
            require(reserveToken.transfer(msg.sender, reserveAmount), "Failed to transfer reserve tokens to the user");
        }

        emit LiquidityRemoved(msg.sender, reserveAmount, _amount);

        return reserveAmount;
    }

    /**
     * @notice 
     * Before calling this function to remove liquidity, users need approve this contract to be able to spend or transfer their pool tokens
     *
     * @dev  
     * The process:     
     * 1.Transfers pool tokens to this contract
     * 2.Calls 'removeLiquidity' on LiquidityPoolConverter contract
     * 3.Calls 'withdraw' on WRBTC contract in order to unwrap WRBTC to RBTC
     * 4.Sneds RBTC and/or other reserve tokens to user
     * 
     * @param _liquidityPoolConverterAddress    address of LiquidityPoolConverter contract
     * @param _amount                           amount of pool tokens to burn
     * @param _reserveTokens                    address of each reserve token. The first element should be the address of WRBTC
     * @param _reserveMinReturnAmounts          minimum return-amount of each reserve token. The first element should be the minimum return-amount of WRBTC
     */
    function removeLiquidityFromV1(
        address _liquidityPoolConverterAddress,
        uint256 _amount, 
        IERC20Token[] memory _reserveTokens, 
        uint256[] memory _reserveMinReturnAmounts
    )   
        public 
        checkAddress(_liquidityPoolConverterAddress)
    {
        require(_amount > 0, "The amount should larger than zero");
        require(address(_reserveTokens[0]) == wrbtcTokenAddress, "The first reserve token must be WRBTC");

        uint256[] memory reserveAmounts = new uint256[](_reserveTokens.length);
        ILiquidityPoolV1Converter _liquidityPoolConverter = ILiquidityPoolV1Converter(_liquidityPoolConverterAddress);
        
        //withdraw always transfers the pool tokens to the caller and the reward tokens to the passed address
        liquidityMiningContract.withdraw(address(_liquidityPoolConverter.token()), _amount, msg.sender);

        uint256 lengthOfToken = _reserveTokens.length;

        uint256[] memory reserveAmountBefore = new uint256[](lengthOfToken);
        for (uint256 i = 0; i < lengthOfToken; i++) {
            reserveAmountBefore[i] = _reserveTokens[i].balanceOf(address(this));
        }

        _liquidityPoolConverter.removeLiquidity(_amount, _reserveTokens, _reserveMinReturnAmounts);

        uint256 reserveAmount;
        bool successOfTransfer;
        for (uint256 i = 1; i < lengthOfToken; i++) {

            reserveAmount = _reserveTokens[i].balanceOf(address(this)).sub(reserveAmountBefore[i]); 
            require(reserveAmount >= _reserveMinReturnAmounts[i], "min return too high");
            reserveAmounts[i] = reserveAmount;
            

            successOfTransfer = IERC20Token(_reserveTokens[i]).transfer(msg.sender, reserveAmount);
            require(successOfTransfer, "Failed to transfer reserve token to user");
        }

        uint256 wrbtcAmount = _reserveTokens[0].balanceOf(address(this)).sub(reserveAmountBefore[0]);
        require(wrbtcAmount >= _reserveMinReturnAmounts[0], "min return too high");
        reserveAmounts[0] = wrbtcAmount;
        IWrbtcERC20(wrbtcTokenAddress).withdraw(wrbtcAmount);
        (bool successOfSendRBTC,) = msg.sender.call.value(wrbtcAmount)("");
        require(successOfSendRBTC, "Failed to send RBTC to user");

        emit LiquidityRemovedFromV1(msg.sender, _reserveTokens, reserveAmounts, _amount);
    }
    
    /**
     * @notice
     * Before calling this function to swap token to RBTC, users need approve this contract to be able to spend or transfer their tokens
     *
     * @param _path         conversion path between two tokens in the network
     * @param _amount       amount to convert from, in the source token
     * @param _minReturn    if the conversion results in an amount smaller than the minimum return - it is cancelled, must be greater than zero
     * 
     * @return amount of tokens received from the conversion
     */
    function convertByPath(
        IERC20Token[] memory _path,
        uint256 _amount, 
        uint256 _minReturn
    ) 
        public 
        payable
        returns(uint256) 
    {    
        ISovrynSwapNetwork _sovrynSwapNetwork =  ISovrynSwapNetwork(sovrynSwapNetworkAddress);
  
        if (msg.value != 0) {
            require(_path[0] == IERC20Token(wrbtcTokenAddress), "Value may only be sent for WRBTC transfers");
            require(_amount == msg.value, "The provided amount should be identical to msg.value");

            IWrbtcERC20(wrbtcTokenAddress).deposit.value(_amount)();

            bool successOfApprove = IWrbtcERC20(wrbtcTokenAddress).approve(sovrynSwapNetworkAddress, _amount);
            require(successOfApprove);

            uint256 _targetTokenAmount = _sovrynSwapNetwork.convertByPath(_path, _amount, _minReturn, msg.sender, address(0), 0);

            emit TokenConverted(msg.sender, _amount, _targetTokenAmount, _path);

            return _targetTokenAmount;
        }
        else {
            require(_path[_path.length-1] == IERC20Token(wrbtcTokenAddress), "It only could be swapped to WRBTC");
            
            IERC20Token _token = IERC20Token(_path[0]);

            bool successOfTransferFrom = _token.transferFrom(msg.sender, address(this), _amount);
            require(successOfTransferFrom);

            bool successOfApprove = _token.approve(sovrynSwapNetworkAddress, _amount);
            require(successOfApprove);
                 
            uint256 _targetTokenAmount = _sovrynSwapNetwork.convertByPath(_path, _amount, _minReturn, address(this), address(0), 0);

            IWrbtcERC20(wrbtcTokenAddress).withdraw(_targetTokenAmount);

            (bool successOfSendRBTC,) = msg.sender.call.value(_targetTokenAmount)("");
            require(successOfSendRBTC, "Failed to send RBTC to user");

            emit TokenConverted(msg.sender, _amount, _targetTokenAmount, _path);

            return _targetTokenAmount;
        }        
    }

    /**
     * @notice provides funds to a lending pool and deposits the pool tokens into the liquidity mining contract.
     * @param loanTokenAddress the address of the loan token (aka lending pool)
     * @param depositAmount he amount of underlying tokens to deposit 
     */
    function addToLendingPool(address loanTokenAddress, uint256 depositAmount) public{
        LoanToken loanToken = LoanToken(loanTokenAddress);
        IERC20Token underlyingAsset = IERC20Token(loanToken.loanTokenAddress());

        //retrieve the underlying asset from the user
        require(underlyingAsset.transferFrom(msg.sender, address(this), depositAmount), "Failed to transfer tokens to the wrapper proxy");

        //add the tokens to the lending pool
        underlyingAsset.approve(loanTokenAddress, depositAmount);
        uint256 minted = loanToken.mint(address(this), depositAmount);

        //deposit the pool tokens in the liquidity mining contract on the sender's behalf
        loanToken.approve(address(liquidityMiningContract), minted);
        liquidityMiningContract.deposit(loanTokenAddress, minted, msg.sender);   

        emit LoanTokensMinted(msg.sender, minted, depositAmount);   
    }

    /**
     * @notice removes funds from the liquidity mining contract, burns them on the lending pool and 
     * provides the underlying asset to the user
     * @param loanTokenAddress the address of the loan token (aka lending pool)
     * @param burnAmount the amount of pool tokens to withdraw from the lending pool and burn
     */
    function removeFromLendingPool(address loanTokenAddress, uint256 burnAmount) public{
        LoanToken loanToken = LoanToken(loanTokenAddress);

        //withdraw always transfers the pool tokens to the caller and the reward tokens to the passed address
        liquidityMiningContract.withdraw(loanTokenAddress, burnAmount, msg.sender);

        //burn pool token and directly send underlying tokens to the receiver
        loanToken.approve(address(liquidityMiningContract), burnAmount);
        uint256 redeemed = loanToken.burn(msg.sender, burnAmount);

        emit LoanTokensBurnt(msg.sender, burnAmount, redeemed);   
    }

}