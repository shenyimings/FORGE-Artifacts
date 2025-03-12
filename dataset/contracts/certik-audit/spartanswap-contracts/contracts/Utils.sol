// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

interface iBEP20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint);
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
}

interface iBASE {
    function mapAddressHasClaimed() external view returns (bool);
    function DAO() external view returns (iDAO);
}

interface iROUTER {
    function totalPooled() external view returns (uint);
    function totalVolume() external view returns (uint);
    function totalFees() external view returns (uint);
    function removeLiquidityTx() external view returns (uint);
    function addLiquidityTx() external view returns (uint);
    function swapTx() external view returns (uint);
    function tokenCount() external view returns(uint);
    function getToken(uint) external view returns(address);
    function getPool(address) external view returns(address payable);
    function addLiquidityForMember(uint inputBase, uint inputToken, address token, address member) external payable returns (uint units);
}

interface iPOOL {
    function genesis() external view returns(uint);
    function baseAmount() external view returns(uint);
    function tokenAmount() external view returns(uint);
    function baseAmountPooled() external view returns(uint);
    function tokenAmountPooled() external view returns(uint);
    function fees() external view returns(uint);
    function volume() external view returns(uint);
    function txCount() external view returns(uint);
    function getBaseAmtPooled(address) external view returns(uint);
    function getTokenAmtPooled(address) external view returns(uint);
    function calcValueInBase(uint) external view returns (uint);
    function calcValueInToken(uint) external view returns (uint);
    function calcTokenPPinBase(uint) external view returns (uint);
    function calcBasePPinToken(uint) external view returns (uint);
}

interface iDAO {
    function ROUTER() external view returns(address);
}

// SafeMath
library SafeMath {

    function add(uint a, uint b) internal pure returns (uint)   {
        uint c = a + b;
        assert(c >= a);
        return c;
    }

    function mul(uint a, uint b) internal pure returns (uint) {
        if (a == 0) {
            return 0;
        }
        uint c = a * b;
        require(c / a == b, "SafeMath");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}

contract Utils {

    using SafeMath for uint;

    address public BASE;
    address public DEPLOYER;

    uint public one = 10**18;

    struct TokenDetails {
        string name;
        string symbol;
        uint decimals;
        uint totalSupply;
        uint balance;
        address tokenAddress;
    }

    struct ListedAssetDetails {
        string name;
        string symbol;
        uint decimals;
        uint totalSupply;
        uint balance;
        address tokenAddress;
        bool hasClaimed;
    }

    struct GlobalDetails {
        uint totalPooled;
        uint totalVolume;
        uint totalFees;
        uint removeLiquidityTx;
        uint addLiquidityTx;
        uint swapTx;
    }

    struct PoolDataStruct {
        address tokenAddress;
        address poolAddress;
        uint genesis;
        uint baseAmount;
        uint tokenAmount;
        uint baseAmountPooled;
        uint tokenAmountPooled;
        uint fees;
        uint volume;
        uint txCount;
        uint poolUnits;
    }

    // Only Deployer can execute
    modifier onlyDeployer() {
        require(msg.sender == DEPLOYER, "DeployerErr");
        _;
    }

    constructor (address _base) public payable {
        BASE = _base;
        DEPLOYER = msg.sender;
    }

    function _DAO() internal view returns(iDAO) {
        return iBASE(BASE).DAO();
    }

    //====================================DATA-HELPERS====================================//

    function getTokenDetails(address token) public view returns (TokenDetails memory tokenDetails){
        return getTokenDetailsWithMember(token, msg.sender);
    }

    function getTokenDetailsWithMember(address token, address member) public view returns (TokenDetails memory tokenDetails){
        if(token == address(0)){
            tokenDetails.name = 'Binance Chain Token';
            tokenDetails.symbol = 'BNB';
            tokenDetails.decimals = 18;
            tokenDetails.totalSupply = 100000000 * one;
            tokenDetails.balance = msg.sender.balance;
        } else {
            tokenDetails.name = iBEP20(token).name();
            tokenDetails.symbol = iBEP20(token).symbol();
            tokenDetails.decimals = iBEP20(token).decimals();
            tokenDetails.totalSupply = iBEP20(token).totalSupply();
            tokenDetails.balance = iBEP20(token).balanceOf(member);
        }
        tokenDetails.tokenAddress = token;
        return tokenDetails;
    }

    function getUnclaimedAssetWithBalance(address token, address member) public view returns (ListedAssetDetails memory listedAssetDetails){
        listedAssetDetails.name = iBEP20(token).name();
        listedAssetDetails.symbol = iBEP20(token).symbol();
        listedAssetDetails.decimals = iBEP20(token).decimals();
        listedAssetDetails.totalSupply = iBEP20(token).totalSupply();
        listedAssetDetails.balance = iBEP20(token).balanceOf(member);
        listedAssetDetails.tokenAddress = token;
        listedAssetDetails.hasClaimed = iBASE(member).mapAddressHasClaimed();
        return listedAssetDetails;
    }

    function getGlobalDetails() public view returns (GlobalDetails memory globalDetails){
        iDAO dao = _DAO();
        globalDetails.totalPooled = iROUTER(dao.ROUTER()).totalPooled();
        globalDetails.totalVolume = iROUTER(dao.ROUTER()).totalVolume();
        globalDetails.totalFees = iROUTER(dao.ROUTER()).totalFees();
        globalDetails.removeLiquidityTx = iROUTER(dao.ROUTER()).removeLiquidityTx();
        globalDetails.addLiquidityTx = iROUTER(dao.ROUTER()).addLiquidityTx();
        globalDetails.swapTx = iROUTER(dao.ROUTER()).swapTx();
        return globalDetails;
    }

    function getPool(address token) public view returns(address pool){
        return iROUTER(_DAO().ROUTER()).getPool(token);
    }
    function tokenCount() public view returns (uint256 count){
        return iROUTER(_DAO().ROUTER()).tokenCount();
    }
    function allTokens() public view returns (address[] memory _allTokens){
        return tokensInRange(0, iROUTER(_DAO().ROUTER()).tokenCount()) ;
    }
    function tokensInRange(uint start, uint count) public view returns (address[] memory someTokens){
        if(start.add(count) > tokenCount()){
            count = tokenCount().sub(start);
        }
        address[] memory result = new address[](count);
        for (uint i = 0; i < count; i++){
            result[i] = iROUTER(_DAO().ROUTER()).getToken(i);
        }
        return result;
    }
    function allPools() public view returns (address[] memory _allPools){
        return poolsInRange(0, tokenCount());
    }
    function poolsInRange(uint start, uint count) public view returns (address[] memory somePools){
        if(start.add(count) > tokenCount()){
            count = tokenCount().sub(start);
        }
        address[] memory result = new address[](count);
        for (uint i = 0; i<count; i++){
            result[i] = getPool(iROUTER(_DAO().ROUTER()).getToken(i));
        }
        return result;
    }

    function getPoolData(address token) public view returns(PoolDataStruct memory poolData){
        address pool = getPool(token);
        poolData.poolAddress = pool;
        poolData.tokenAddress = token;
        poolData.genesis = iPOOL(pool).genesis();
        poolData.baseAmount = iPOOL(pool).baseAmount();
        poolData.tokenAmount = iPOOL(pool).tokenAmount();
        poolData.baseAmountPooled = iPOOL(pool).baseAmountPooled();
        poolData.tokenAmountPooled = iPOOL(pool).tokenAmountPooled();
        poolData.fees = iPOOL(pool).fees();
        poolData.volume = iPOOL(pool).volume();
        poolData.txCount = iPOOL(pool).txCount();
        poolData.poolUnits = iBEP20(pool).totalSupply();
        return poolData;
    }

    function getMemberShare(address token, address member) public view returns(uint baseAmount, uint tokenAmount){
        address pool = getPool(token);
        uint units = iBEP20(pool).balanceOf(member);
        return getPoolShare(token, units);
    }

    function getPoolShare(address token, uint units) public view returns(uint baseAmount, uint tokenAmount){
        address pool = getPool(token);
        baseAmount = calcShare(units, iBEP20(pool).totalSupply(), iPOOL(pool).baseAmount());
        tokenAmount = calcShare(units, iBEP20(pool).totalSupply(), iPOOL(pool).tokenAmount());
        return (baseAmount, tokenAmount);
    }

    function getShareOfBaseAmount(address token, address member) public view returns(uint baseAmount){
        address pool = getPool(token);
        uint units = iBEP20(pool).balanceOf(member);
        return calcShare(units, iBEP20(pool).totalSupply(), iPOOL(pool).baseAmount());
    }
    function getShareOfTokenAmount(address token, address member) public view returns(uint baseAmount){
        address pool = getPool(token);
        uint units = iBEP20(pool).balanceOf(member);
        return calcShare(units, iBEP20(pool).totalSupply(), iPOOL(pool).tokenAmount());
    }

    function getPoolShareAssym(address token, uint units, bool toBase) public view returns(uint baseAmount, uint tokenAmount, uint outputAmt){
        address pool = getPool(token);
        if(toBase){
            baseAmount = calcAsymmetricShare(units, iBEP20(pool).totalSupply(), iPOOL(pool).baseAmount());
            tokenAmount = 0;
            outputAmt = baseAmount;
        } else {
            baseAmount = 0;
            tokenAmount = calcAsymmetricShare(units, iBEP20(pool).totalSupply(), iPOOL(pool).tokenAmount());
            outputAmt = tokenAmount;
        }
        return (baseAmount, tokenAmount, outputAmt);
    }

    function getPoolAge(address token) public view returns (uint daysSinceGenesis){
        address pool = getPool(token);
        uint genesis = iPOOL(pool).genesis();
        if(now < genesis.add(86400)){
            return 1;
        } else {
            return (now.sub(genesis)).div(86400);
        }
    }

    function getPoolROI(address token) public view returns (uint roi){
        address pool = getPool(token);
        uint _baseStart = iPOOL(pool).baseAmountPooled().mul(2);
        uint _baseEnd = iPOOL(pool).baseAmount().mul(2);
        uint _ROIS = (_baseEnd.mul(10000)).div(_baseStart);
        uint _tokenStart = iPOOL(pool).tokenAmountPooled().mul(2);
        uint _tokenEnd = iPOOL(pool).tokenAmount().mul(2);
        uint _ROIA = (_tokenEnd.mul(10000)).div(_tokenStart);
        return (_ROIS + _ROIA).div(2);
   }

   function getPoolAPY(address token) public view returns (uint apy){
        uint avgROI = getPoolROI(token);
        uint poolAge = getPoolAge(token);
        return (avgROI.mul(365)).div(poolAge);
   }

    function isMember(address token, address member) public view returns(bool){
        address pool = getPool(token);
        if (iBEP20(pool).balanceOf(member) > 0){
            return true;
        } else {
            return false;
        }
    }

    //====================================PRICING====================================//

    function calcValueInBase(address token, uint amount) public view returns (uint value){
       address pool = getPool(token);
       return calcValueInBaseWithPool(pool, amount);
    }

    function calcValueInToken(address token, uint amount) public view returns (uint value){
        address pool = getPool(token);
        return calcValueInTokenWithPool(pool, amount);
    }

    function calcTokenPPinBase(address token, uint amount) public view returns (uint _output){
        address pool = getPool(token);
        return  calcTokenPPinBaseWithPool(pool, amount);
   }

    function calcBasePPinToken(address token, uint amount) public view returns (uint _output){
        address pool = getPool(token);
        return  calcValueInBaseWithPool(pool, amount);
    }

    function calcValueInBaseWithPool(address pool, uint amount) public view returns (uint value){
       uint _baseAmount = iPOOL(pool).baseAmount();
       uint _tokenAmount = iPOOL(pool).tokenAmount();
       return (amount.mul(_baseAmount)).div(_tokenAmount);
    }

    function calcValueInTokenWithPool(address pool, uint amount) public view returns (uint value){
        uint _baseAmount = iPOOL(pool).baseAmount();
        uint _tokenAmount = iPOOL(pool).tokenAmount();
        return (amount.mul(_tokenAmount)).div(_baseAmount);
    }

    function calcTokenPPinBaseWithPool(address pool, uint amount) public view returns (uint _output){
        uint _baseAmount = iPOOL(pool).baseAmount();
        uint _tokenAmount = iPOOL(pool).tokenAmount();
        return  calcSwapOutput(amount, _tokenAmount, _baseAmount);
   }

    function calcBasePPinTokenWithPool(address pool, uint amount) public view returns (uint _output){
        uint _baseAmount = iPOOL(pool).baseAmount();
        uint _tokenAmount = iPOOL(pool).tokenAmount();
        return  calcSwapOutput(amount, _baseAmount, _tokenAmount);
    }

    //====================================CORE-MATH====================================//

    function calcPart(uint bp, uint total) public pure returns (uint part){
        // 10,000 basis points = 100.00%
        require((bp <= 10000) && (bp > 0), "Must be correct BP");
        return calcShare(bp, 10000, total);
    }

    function calcLiquidityShare(uint units, address token, address pool, address member) public view returns (uint share){
        // share = amount * part/total
        // address pool = getPool(token);
        uint amount = iBEP20(token).balanceOf(pool);
        uint totalSupply = iBEP20(pool).totalSupply();
        return(amount.mul(units)).div(totalSupply);
    }

    function calcShare(uint part, uint total, uint amount) public pure returns (uint share){
        // share = amount * part/total
        return(amount.mul(part)).div(total);
    }

    function  calcSwapOutput(uint x, uint X, uint Y) public pure returns (uint output){
        // y = (x * X * Y )/(x + X)^2
        uint numerator = x.mul(X.mul(Y));
        uint denominator = (x.add(X)).mul(x.add(X));
        return numerator.div(denominator);
    }

    function  calcSwapFee(uint x, uint X, uint Y) public pure returns (uint output){
        // y = (x * x * Y) / (x + X)^2
        uint numerator = x.mul(x.mul(Y));
        uint denominator = (x.add(X)).mul(x.add(X));
        return numerator.div(denominator);
    }

    function calcLiquidityUnits(uint b, uint B, uint t, uint T, uint P) public view returns (uint units){
        if(P == 0){
            return b;
        } else {
            // units = ((P (t B + T b))/(2 T B)) * slipAdjustment
            // P * (part1 + part2) / (part3) * slipAdjustment
            uint slipAdjustment = getSlipAdustment(b, B, t, T);
            uint part1 = t.mul(B);
            uint part2 = T.mul(b);
            uint part3 = T.mul(B).mul(2);
            uint _units = (P.mul(part1.add(part2))).div(part3);
            return _units.mul(slipAdjustment).div(one);  // Divide by 10**18
        }
    }

    function getSlipAdustment(uint b, uint B, uint t, uint T) public view returns (uint slipAdjustment){
        // slipAdjustment = (1 - ABS((B t - b T)/((2 b + B) (t + T))))
        // 1 - ABS(part1 - part2)/(part3 * part4))
        uint part1 = B.mul(t);
        uint part2 = b.mul(T);
        uint part3 = b.mul(2).add(B);
        uint part4 = t.add(T);
        uint numerator;
        if(part1 > part2){
            numerator = part1.sub(part2);
        } else {
            numerator = part2.sub(part1);
        }
        uint denominator = part3.mul(part4);
        return one.sub((numerator.mul(one)).div(denominator)); // Multiply by 10**18
    }

    function calcAsymmetricShare(uint u, uint U, uint A) public pure returns (uint share){
        // share = (u * U * (2 * A^2 - 2 * U * u + U^2))/U^3
        // (part1 * (part2 - part3 + part4)) / part5
        uint part1 = u.mul(A);
        uint part2 = U.mul(U).mul(2);
        uint part3 = U.mul(u).mul(2);
        uint part4 = u.mul(u);
        uint numerator = part1.mul(part2.sub(part3).add(part4));
        uint part5 = U.mul(U).mul(U);
        return numerator.div(part5);
    }

}