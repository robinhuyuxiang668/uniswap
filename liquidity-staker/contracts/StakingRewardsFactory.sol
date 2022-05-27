pragma solidity ^0.5.16;

import 'openzeppelin-solidity-2.3.0/contracts/token/ERC20/IERC20.sol';
import 'openzeppelin-solidity-2.3.0/contracts/ownership/Ownable.sol';

import './StakingRewards.sol';

contract StakingRewardsFactory is Ownable {
   
    address public immutable rewardsToken;//用作奖励的代币，其实就是 UNI 代币
    uint public immutable stakingRewardsGenesis;//质押挖矿开始的时间
    
    address[] public stakingTokens;//用来质押的代币数组，一般就是各交易对的 LPToken
    
    struct StakingRewardsInfo {
        address stakingRewards;//质押合约地址
        uint rewardAmount;//质押合约每周期的奖励总量
    }

    // 保存质押代币LP 和质押合约信息之间的映射
    mapping(address => StakingRewardsInfo) public stakingRewardsInfoByStakingToken;

    constructor(
        address _rewardsToken,
        uint _stakingRewardsGenesis
    ) Ownable() public {
        require(_stakingRewardsGenesis >= block.timestamp, 'StakingRewardsFactory::constructor: genesis too soon');

        rewardsToken = _rewardsToken;
        stakingRewardsGenesis = _stakingRewardsGenesis;
    }
 
     // 部署质押奖励合约  stakingToken：Lp代币
    function deploy(address stakingToken, uint rewardAmount) public onlyOwner {
        StakingRewardsInfo storage info = stakingRewardsInfoByStakingToken[stakingToken];
        require(info.stakingRewards == address(0), 'StakingRewardsFactory::deploy: already deployed');

        info.stakingRewards = address(new StakingRewards(/*_rewardsDistribution=*/ address(this), rewardsToken, stakingToken));
        info.rewardAmount = rewardAmount;
        stakingTokens.push(stakingToken);
    }


    function notifyRewardAmounts() public {
        require(stakingTokens.length > 0, 'StakingRewardsFactory::notifyRewardAmounts: called before any deploys');
        for (uint i = 0; i < stakingTokens.length; i++) {
            notifyRewardAmount(stakingTokens[i]);
        }
    }

    //挖矿奖励的代币UNI 转入到质押合约中开始挖矿（前提是需要先将UNI 先转入该工厂合约）
    function notifyRewardAmount(address stakingToken) public {
        //当前区块的时间需大于等于质押挖矿的开始时间
        require(block.timestamp >= stakingRewardsGenesis, 'StakingRewardsFactory::notifyRewardAmount: not ready');

        StakingRewardsInfo storage info = stakingRewardsInfoByStakingToken[stakingToken];
        //要求 质押合约地址不能为零地址，否则说明还没部署。
        require(info.stakingRewards != address(0), 'StakingRewardsFactory::notifyRewardAmount: not deployed');

        if (info.rewardAmount > 0) {
            uint rewardAmount = info.rewardAmount;
            //这里先在转账前置0而不是放在转账后 ,因为如果有两个几乎同时调用该方法
            //会向质押合约重复发奖励代币
            info.rewardAmount = 0;

            require(
                IERC20(rewardsToken).transfer(info.stakingRewards, rewardAmount),
                'StakingRewardsFactory::notifyRewardAmount: transfer failed'
            );
            StakingRewards(info.stakingRewards).notifyRewardAmount(rewardAmount);
        }
    }
}