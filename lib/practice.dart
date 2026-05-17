import 'package:flutter/material.dart';

class practice extends StatefulWidget {
  const practice({super.key});

  @override
  State<practice> createState() => _practiceState();
}

class _practiceState extends State<practice> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Column(
        children: [
          Container(),
          Row(
            children: [
              Container(),
              Column(
                children: [

                  Container(),
                  Container()
                    ],
                  )


            ],
          )

        ],
      )
      ,
    );
  }
}
