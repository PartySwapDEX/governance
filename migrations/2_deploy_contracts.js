const TreasuryVester = artifacts.require("TreasuryVester");
const LiquidityPoolManager = artifacts.require("LiquidityPoolManager");
// const PARTY = '0xb68Dd903198339f1818Fb3710AB4Ea2Ff85231B8'; //FUJI
const PARTY = '0x69A61f38Df59CBB51962E69C54D39184E21C27Ec'; //MAINNET

module.exports = function (deployer) {
  deployer.deploy(TreasuryVester, PARTY).then(
    () => {
      const WAVAX = '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7'; //MAINNET
      // const WAVAX = '0xd00ae08403B9bbb9124bB305C09058E32C39A48c'; //FUJI
      return deployer.deploy(LiquidityPoolManager, WAVAX, PARTY, TreasuryVester.address)
    }
  );
};
