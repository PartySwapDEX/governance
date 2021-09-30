function main(){
  let vestingAmmount = +process.argv[2];
  const halvingPeriod = +process.argv[3];
  const days = +process.argv[4];
  let totalVested = 0;
  let nextSlash = halvingPeriod;

  for(let i = 0; i <= +days; i++){

    if(nextSlash === 0){
      nextSlash = halvingPeriod - 1;
      vestingAmmount = vestingAmmount * 0.75;
    } else {
      --nextSlash;
    }

    totalVested += vestingAmmount;

    console.log('Day: ', i, ', Vested: ', vestingAmmount);

    if(i == days){
      console.log('Reached: ', totalVested);

    }

    if(totalVested >= 48125000){
      console.log('Reached top');
      break;
    }
  }
}

main();