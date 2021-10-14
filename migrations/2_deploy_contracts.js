const TreasuryVester = artifacts.require("TreasuryVester");
const LiquidityPoolManager = artifacts.require("LiquidityPoolManager");

const PARTY = '0x02048Fe5d5849Bfdb0FF2150c443c2a2A28fc0dE'; //FUJI-v2
// const PARTY = '0x3EA3e5C6957581F3e70b2C33721D4E6844f60619'; //MAINNET-v2

// const WAVAX = '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7'; //MAINNET
const WAVAX = '0xd00ae08403B9bbb9124bB305C09058E32C39A48c'; //FUJI

const STABLETOKEN = '0x2058ec2791dD28b6f67DB836ddf87534F4Bbdf22'; //FUJISTABLE ADDRESS
// const STABLETOKEN = '0xc7198437980c041c805A1EDcbA50c1Ce5db95118'; //USDT.e


// Just use this if deploying entire solution
// module.exports = function (deployer) {
//   deployer.deploy(TreasuryVester, PARTY).then(
//     () => {
//       return deployer.deploy(LiquidityPoolManager, WAVAX, PARTY, STABLETOKEN, TreasuryVester.address)
//     }
//   );
// };

module.exports = function (deployer) {
  deployer.deploy(TreasuryVester, PARTY);
};