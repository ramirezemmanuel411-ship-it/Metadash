import 'package:metadash/data/datasources/food_remote_datasource.dart';
import 'package:metadash/services/raw_search_debug_store.dart';
import 'dart:convert';
import 'dart:io';

void main() async {
  final datasource = FoodRemoteDatasource();
  
  final queries = ['Coke', 'Pepsi', 'Pizza Hut', 'Hershey'];
  final allResults = <String, dynamic>{};
  
  for (final query in queries) {
    stderr.writeln('\nSEARCHING: $query');
    
    // Search both OFF and USDA
    await datasource.searchBoth(query);
    
    // Get results from debug store
    final results = RawSearchDebugStore.latestResults;
    stderr.writeln('Total raw results for "$query": ${results.length}');
    
    // Store ALL results (not just first 20)
    final jsonList = results.map((r) => r.toJson()).toList();
    allResults[query] = {
      'total_results': results.length,
      'results': jsonList
    };
    
    // Clear for next search
    RawSearchDebugStore.clear();
  }
  
  // Output final JSON structure to stdout only
  print(jsonEncode(allResults));
}
